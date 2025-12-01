//
//  JobsRichText.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 9/29/25.
//

import UIKit
// MARK: - 基础 Builder
@inline(__always)
public func jobsMakeParagraphStyle(_ block: (NSMutableParagraphStyle) -> Void) -> NSMutableParagraphStyle {
    let ps = NSMutableParagraphStyle()
    block(ps)
    return ps
}

@inline(__always)
public func jobsMakeTextAttachment(_ block: (NSTextAttachment) -> Void) -> NSTextAttachment {
    let att = NSTextAttachment()
    block(att)
    return att
}

@inline(__always)
public func jobsMakeMutableAttributedString(_ block: (NSMutableAttributedString) -> Void) -> NSMutableAttributedString {
    let ms = NSMutableAttributedString()
    block(ms)
    return ms
}
// MARK: - 数据模型
public struct JobsRichRun {
    // 文本 or 附件：二选一
    public enum Payload {
        case text(String)
        case attachment(NSTextAttachment, CGSize?) // 可选显示尺寸
    }
    public var payload: Payload
    // 属性
    public var font: UIFont?
    public var textColor: UIColor?
    public var underlineStyle: NSUnderlineStyle?
    public var underlineColor: UIColor?
    public var strikethroughStyle: NSUnderlineStyle?
    public var strikethroughColor: UIColor?
    public var paragraphStyle: NSParagraphStyle?
    public var link: String? // "click://..."
    // 便捷链式
    public init(_ payload: Payload) { self.payload = payload }

    @discardableResult public func font(_ v: UIFont?) -> JobsRichRun { var s = self; s.font = v; return s }
    @discardableResult public func color(_ v: UIColor?) -> JobsRichRun { var s = self; s.textColor = v; return s }
    @discardableResult public func underline(_ v: NSUnderlineStyle?, color: UIColor? = nil) -> JobsRichRun { var s = self; s.underlineStyle = v; s.underlineColor = color; return s }
    @discardableResult public func strike(_ v: NSUnderlineStyle?, color: UIColor? = nil) -> JobsRichRun { var s = self; s.strikethroughStyle = v; s.strikethroughColor = color; return s }
    @discardableResult public func paragraph(_ v: NSParagraphStyle?) -> JobsRichRun { var s = self; s.paragraphStyle = v; return s }
    @discardableResult public func link(_ v: String?) -> JobsRichRun { var s = self; s.link = v; return s }
}
// MARK: - 拼装器
public struct JobsRichText {
    /// 核心：把一组 run（文本片段/附件）合成为 NSMutableAttributedString
    public static func make(_ runs: [JobsRichRun],paragraphStyle: NSMutableParagraphStyle? = nil) -> NSMutableAttributedString {
        // 先串接纯字符串（附件位置占位为 U+FFFC）
        var finalString = ""
        var pieces: [(range: NSRange, run: JobsRichRun)] = []
        var cursor = 0

        for run in runs {
            switch run.payload {
            case .text(let s):
                let length = (s as NSString).length
                let range = NSRange(location: cursor, length: length)
                pieces.append((range, run))
                finalString += s
                cursor += length
            case .attachment:
                // attachment 使用特殊占位符（Object Replacement Character）
                finalString += "\u{FFFC}"
                let range = NSRange(location: cursor, length: 1)
                pieces.append((range, run))
                cursor += 1
            }
        }

        let ms = NSMutableAttributedString(string: finalString)
        // 1) 全局段落样式（可选）
        if let ps = paragraphStyle {
            ms.addAttribute(.paragraphStyle, value: ps, range: NSRange(location: 0, length: ms.length))
        }
        // 2) 逐段落下发属性
        for (range, run) in pieces {
            switch run.payload {
            case .attachment(let att, let size):
                if let size {
                    att.bounds = CGRect(origin: .zero, size: size)
                }
                ms.addAttribute(.attachment, value: att, range: range)

            case .text:
                if let font = run.font {
                    ms.addAttribute(.font, value: font, range: range)
                }
                if let color = run.textColor {
                    ms.addAttribute(.foregroundColor, value: color, range: range)
                }
                if let u = run.underlineStyle {
                    ms.addAttribute(.underlineStyle, value: u.rawValue, range: range)
                }
                if let uc = run.underlineColor {
                    ms.addAttribute(.underlineColor, value: uc, range: range)
                }
                if let s = run.strikethroughStyle {
                    ms.addAttribute(.strikethroughStyle, value: s.rawValue, range: range)
                }
                if let sc = run.strikethroughColor {
                    ms.addAttribute(.strikethroughColor, value: sc, range: range)
                }
                if let ps = run.paragraphStyle {
                    ms.addAttribute(.paragraphStyle, value: ps, range: range)
                }
                if let url = run.link {
                    ms.addAttribute(.link, value: url, range: range)
                }
            }
        }

        return ms
    }
    /// 等价工具：中划线
    public static func strike(_ s: String) -> NSAttributedString {
        NSMutableAttributedString(string: s, attributes: [
            .strikethroughStyle: NSUnderlineStyle.single.rawValue
        ])
    }
    /// 等价工具：下划线
    public static func underline(_ s: String) -> NSAttributedString {
        NSMutableAttributedString(string: s, attributes: [
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ])
    }
}
