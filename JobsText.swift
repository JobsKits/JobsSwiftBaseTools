//
//  JobsText.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/23/25.
//

import Foundation
#if os(OSX)
import AppKit
#endif

#if os(iOS) || os(tvOS)
import UIKit
#endif
/// 统一载体：既可承载纯文本，也可承载富文本（不依赖 UIKit）
/// Swift 并发里，跨 actor / 跨任务传递的数据，如果是 Sendable，编译器才认为你这么用是安全的。
public struct JobsText: Sendable {
    // ⚠️ 注意：NSAttributedString 非 Sendable
    // 这里的 Storage 不再声明 Sendable，而是在下面用 @unchecked Sendable 明确“我保证只读与拷贝”。
    public enum Storage {
        case plain(String)
        case attributed(NSAttributedString)
    }

    public let storage: Storage // 内部实现：真正的数据、复制策略、观察逻辑
    // MARK: - 构造
    public init(_ string: String) {
        self.storage = .plain(string)
    }

    public init(_ attributed: NSAttributedString) {
        // 存储不可变副本，防止跨线程共享可变对象
        self.storage = .attributed(attributed.copy() as! NSAttributedString)
    }

    @available(iOS 15.0, macOS 12.0, *)
    public init(_ swiftAttr: AttributedString) {
        self.storage = .attributed(NSAttributedString(swiftAttr))
    }
    // 字面量支持：可直接写 let t: JobsText = "hello"
    public init(stringLiteral value: StringLiteralType) {
        self.storage = .plain(value)
    }
}
// MARK: - 并发声明
// Storage 持有 NSAttributedString（非 Sendable）。
// 我们确保：
// 1) 只在 init 时存入不可变 copy；
// 2) 一切变换都返回新实例，不做原地修改；
// 3) asAttributedString() 返回 copy。
// 因此这里使用 @unchecked Sendable。
extension JobsText.Storage: @unchecked Sendable {}

// MARK: - 字面量协议 & 描述
extension JobsText: ExpressibleByStringLiteral {}
extension JobsText: CustomStringConvertible {
    public var description: String { asString }
}
// MARK: - 基础访问
public extension JobsText {
    /// 仅当是纯文本时为 true
    var isPlain: Bool {
        if case .plain = storage { return true } else { return false }
    }
    /// ⬆️ 不管 plain/attributed，都给 NSAttributedString
    var asAttributed: NSAttributedString {
        switch storage {
        case .plain(let s):
            return NSAttributedString(string: s)
        case .attributed(let at):
            return at
        }
    }
    /// ⬇️ 不管 plain/attributed，都给String（富文本会丢失样式，只保留 .string）
    var asString: String {
        switch storage {
        case .plain(let s): return s
        case .attributed(let a): return a.string
        }
    }
    /// 只关心富文本时用；纯文本则返回 nil
    var attributed: NSAttributedString? {
        switch storage {
        case .plain:              return nil
        case .attributed(let at): return at
        }
    }
    /// 以 NSAttributedString 取出
    /// - Parameter baseAttributes: 若本体是纯文本，应用这些基础属性生成富文本；若本体是富文本则忽略。
    func asAttributedString(baseAttributes: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        switch storage {
        case .plain(let s):
            if let attrs = baseAttributes, !attrs.isEmpty {
                return NSAttributedString(string: s, attributes: attrs)
            } else {
                return NSAttributedString(string: s)
            }
        case .attributed(let a):
            // 返回不可变副本，保持跨线程只读语义
            return a.copy() as! NSAttributedString
        }
    }
}
// MARK: - 变换 & 组合
public extension JobsText {
    /// 在现有文本上“叠加”属性：
    /// - 若为纯文本：直接用 new 包一层。
    /// - 若为富文本：在每个 range 上 merge（已有的属性保持，冲突键以 new 覆盖）。
    func applying(_ new: [NSAttributedString.Key: Any]) -> JobsText {
        guard !new.isEmpty else { return self }
        switch storage {
        case .plain(let s):
            return JobsText(NSAttributedString(string: s, attributes: new))
        case .attributed(let a):
            let m = NSMutableAttributedString(attributedString: a)
            let full = NSRange(location: 0, length: m.length)
            m.enumerateAttributes(in: full, options: []) { attrs, range, _ in
                var merged = attrs
                new.forEach { k, v in merged[k] = v } // 以 new 覆盖冲突
                m.setAttributes(merged, range: range)
            }
            // 新实例，保持不可变存储
            return JobsText(m)
        }
    }
    /// 自定义映射到底层 NSAttributedString（给你完全控制权）
    func mapAttributed(_ transform: (NSAttributedString) -> NSAttributedString) -> JobsText {
        switch storage {
        case .plain(let s):
            return JobsText(transform(NSAttributedString(string: s)))
        case .attributed(let a):
            return JobsText(transform(a))
        }
    }
    /// 拼接
    static func + (lhs: JobsText, rhs: JobsText) -> JobsText {
        switch (lhs.storage, rhs.storage) {
        case (.plain(let l), .plain(let r)):
            return JobsText(l + r)
        default:
            let lm = NSMutableAttributedString(attributedString: lhs.asAttributedString())
            lm.append(rhs.asAttributedString())
            return JobsText(lm)
        }
    }
}
// MARK: - 相等性（基于 NSAttributedString 的 isEqual）
extension JobsText: Equatable {
    public static func == (l: JobsText, r: JobsText) -> Bool {
        switch (l.storage, r.storage) {
        case (.plain(let ls), .plain(let rs)):
            return ls == rs
        default:
            return l.asAttributedString().isEqual(r.asAttributedString())
        }
    }
}
// MARK: - （可选）序列化：RTF/HTML 编解码帮助
public extension JobsText {
    /// 尝试以 RTF 表示导出（纯文本将被转换为带默认属性的 RTF）
    func rtfData() -> Data? {
        let a = asAttributedString()
        return try? a.data(from: NSRange(location: 0, length: a.length),
                           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
    }
    /// 从 RTF/RTFD/HTML 等数据恢复富文本
    static func from(data: Data,
                     options: [NSAttributedString.DocumentReadingOptionKey: Any] = [:]) -> JobsText? {
        if let a = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return JobsText(a)
        }
        return nil
    }
}
