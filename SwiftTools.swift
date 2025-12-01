//
//  SwiftTools.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 9/25/25.
//

import Foundation

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif

// MARK: - 扩展 Int 与 JXAuthCode 的比较
public func ==(lhs: Int?, rhs: JXAuthCode) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs == Int(rhs.rawValue)
}

public func ==(lhs: Int, rhs: JXAuthCode) -> Bool {
    return lhs == Int(rhs.rawValue)
}

public func ==(lhs: JXAuthCode, rhs: Int?) -> Bool {
    guard let rhs = rhs else { return false }
    return Int(lhs.rawValue) == rhs
}

public func ==(lhs: JXAuthCode, rhs: Int) -> Bool {
    return Int(lhs.rawValue) == rhs
}
// MARK: - 扩展 Int 与 JXAuthCode 的不等于
public func !=(lhs: Int?, rhs: JXAuthCode) -> Bool {
    !(lhs == rhs)
}

public func !=(lhs: Int, rhs: JXAuthCode) -> Bool {
    !(lhs == rhs)
}

public func !=(lhs: JXAuthCode, rhs: Int?) -> Bool {
    !(lhs == rhs)
}

public func !=(lhs: JXAuthCode, rhs: Int) -> Bool {
    !(lhs == rhs)
}
// MARK: - 工具：常用格式化 & 校验
enum JobsFormatters {
    /// 仅保留数字与一个小数点，并限制到 scale 位小数（默认 2 位）
    static func decimal(scale: Int = 2) -> (String) -> String {
        return { s in
            let chars = Array(s)
            var out: [Character] = []
            var dotSeen = false
            var fracCount = 0
            for ch in chars {
                if ch.isNumber { // 0~9
                    if dotSeen {
                        if fracCount < scale {
                            out.append(ch)
                            fracCount += 1
                        }
                    } else {
                        out.append(ch)
                    }
                } else if ch == "." && !dotSeen {
                    // 第一颗小数点
                    dotSeen = true
                    if out.isEmpty { out.append("0") } // 形如 ".1" -> "0.1"
                    out.append(".")
                }
            }
            // 去掉首部多余 0：保留 "0" 或 "0.xxx"
            // （注意：不做进位，仅做清洗）
            let str = String(out)
            if str.hasPrefix("00") {
                // 粗暴去多零
                let trimmed = str.drop(while: { $0 == "0" })
                if trimmed.first == "." { return "0" + trimmed }
                return trimmed.isEmpty ? "0" : String(trimmed)
            }
            return str.isEmpty ? "" : str
        }
    }
    /// 中国大陆手机号 3-4-4 分组（仅清洗与分组，不做合法号段校验）
    static func phoneCN() -> (String) -> String {
        return { s in
            let digits = s.filter(\.isNumber)
            var parts: [String] = []
            let c = digits.count
            if c <= 3 {
                parts = [digits]
            } else if c <= 7 {
                let p1 = String(digits.prefix(3))
                let p2 = String(digits.dropFirst(3))
                parts = [p1, p2]
            } else {
                let p1 = String(digits.prefix(3))
                let p2 = String(digits.dropFirst(3).prefix(4))
                let p3 = String(digits.dropFirst(7).prefix(4))
                parts = [p1, p2, p3].filter { !$0.isEmpty }
            }
            return parts.joined(separator: " ")
        }
    }
}
/**
     // MARK: - 打印示例
     private func printDemo() {
         // 1) 普通文本 / 参数混合
         log("你好，世界", 123, true)
         // 2) JSON：自动识别 String/Data/字典/数组（默认 pretty + 中文还原）
         log(#"{"key":"\u7231\u60c5"}"#)                 // String JSON
         log(["user": "张三", "tags": ["iOS","Swift"]])  // 字典/数组
         log(DataFromNetwork(
             statusCode: 200,
             message: "OK",
             url: URL(string: "https://api.example.com/users")!,
             headers: ["Content-Type": "application/json"],
             body: #"{"user":"\u5f20\u4e09","tags":["iOS","Swift"],"ok":true}"#.data(using: .utf8),
             receivedAt: Date(),
             retryable: false
         ))                            // Data
         // 3) 对象：自动反射为 JSON（防环、可控深度）
         struct User { let id: Int; let name: String }
         let u = User(id: 1, name: "张三")
         log(u)                      // .auto 下会转对象 JSON
         log(u, mode: .object)       // 强制对象模式（不走 stringify）
         // 4) 指定级别（仍是一个入口）
         log("启动完成", level: .info)
         log("接口慢",  level: .warn)
         log(["err": "timeout"], level: .error)
         log(["arr": ["\\u7231\\u60c5", 1]], level: .debug)
     }
 */
// MARK: - JobsLog（统一入口）
public enum JobsLog {
    // 全局开关
    public static var enabled: Bool = true
    public static var showThread: Bool = true
    // 等级（可选，默认 .plain）
    public enum Level: String { case plain = "LOG", info = "INFO", warn = "WARN", error = "ERROR", debug = "DEBUG"
        var symbol: String {
            switch self {
            case .plain: return "📝"
            case .info:  return "ℹ️"
            case .warn:  return "⚠️"
            case .error: return "❌"
            case .debug: return "🐞"
            }
        }
    }
    // 模式（统一入口：自动识别/强制 JSON/强制对象/纯文本）
    public enum Mode { case auto, json, object, plain }
    // 统一入口（只用这个）
    public static func log(_ items: Any...,
                           level: Level = .plain,
                           mode: Mode = .auto,
                           prettyJSON: Bool = true,
                           maxDepth: Int = 3,
                           separator: String = " ",
                           terminator: String = "\n",
                           file: String = #file, line: Int = #line, function: String = #function)
    {
        guard enabled else { return }
        let msg = items.map { render($0, mode: mode, prettyJSON: prettyJSON, maxDepth: maxDepth) }
                       .joined(separator: separator)
        let fileName = (file as NSString).lastPathComponent
        let threadPart: String = {
            guard showThread else { return "" }
            let name = Thread.isMainThread ? "main"
            : (String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) ?? "bg")
            return " | \(name)"
        }()

        Swift.print("\(level.symbol) \(timeNow()) | \(fileName):\(line) | \(function)\(threadPart) → \(msg)",
                    terminator: terminator)
    }
    // 统一渲染：根据模式/类型输出
    private static func render(_ any: Any, mode: Mode, prettyJSON: Bool, maxDepth: Int) -> String {
        switch mode {
        case .plain:
            return stringify(any)

        case .json:
            return toJSONString(any, pretty: prettyJSON, decodeUnicode: true) ?? stringify(any)

        case .object:
            return toJSONStringFromObject(any, pretty: prettyJSON, maxDepth: maxDepth) ?? stringify(any)

        case .auto:
            // 1) 明确是 JSON 的几种：Data / String 以 { 或 [
            if let s = toJSONString(any, pretty: prettyJSON, decodeUnicode: true) { return s }
            // 2) Swift 原生容器能成为 JSON（[Any] / [AnyHashable:Any]）
            if let s = tryJSONFromContainers(any, pretty: prettyJSON) { return s }
            // 3) 其他对象 → 反射为 JSON
            if let s = toJSONStringFromObject(any, pretty: prettyJSON, maxDepth: maxDepth) { return s }
            // 4) 兜底：人类可读 stringify（会解码 \uXXXX）
            return stringify(any)
        }
    }
    // ---------- 基础工具 ----------
    private static func timeNow() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; f.locale = Locale(identifier: "zh_CN")
        return f.string(from: Date())
    }
    // 人类可读 stringify（递归容器 + Unicode 反转义）
    private static func stringify(_ v: Any) -> String {
        if case Optional<Any>.none = v as Any? { return "nil" }
        let x = v

        if let s = x as? String { return decodeUnicodeEscapes(s) }
        if let s = x as? NSString { return decodeUnicodeEscapes(s as String) }

        if let data = x as? Data,
           let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted]),
           let s = String(data: pretty, encoding: .utf8) { return decodeUnicodeEscapes(s) }

        if let arr = x as? [Any] {
            return "[" + arr.map { stringify($0) }.joined(separator: ", ") + "]"
        }
        if let nsArr = x as? NSArray {
            return "[" + nsArr.map { stringify($0) }.joined(separator: ", ") + "]"
        }
        if let set = x as? Set<AnyHashable> {
            return "Set([" + set.map { stringify($0) }.joined(separator: ", ") + "])"
        }

        if let dict = x as? [AnyHashable: Any] {
            let body = dict.map { k, v -> String in
                let ks = stringify(k)
                if v is String || v is NSString {
                    return "\"\(ks)\": \"\(stringify(v))\""
                } else {
                    return "\"\(ks)\": \(stringify(v))"
                }
            }.joined(separator: ", ")
            return "{\(body)}"
        }
        if let nsDict = x as? NSDictionary {
            let body = nsDict.map { (pair) -> String in
                let (k, v) = pair as! (AnyHashable, Any)
                let ks = stringify(k)
                if v is String || v is NSString {
                    return "\"\(ks)\": \"\(stringify(v))\""
                } else {
                    return "\"\(ks)\": \(stringify(v))"
                }
            }.joined(separator: ", ")
            return "{\(body)}"
        }
        return decodeUnicodeEscapes(String(describing: x))
    }
    // 更稳的 Unicode 反转义：支持 \uXXXX / \UXXXXXXXX，且能处理整段文本
    private static func decodeUnicodeEscapes(_ s: String) -> String {
        // 先把可能的 “双反斜杠转义” 规整为单反斜杠，避免被当作普通字符
        let normalized = s
            .replacingOccurrences(of: #"\\u"#, with: #"\u"#)
            .replacingOccurrences(of: #"\\U"#, with: #"\U"#)

        let ms = NSMutableString(string: normalized)
        // "Any-Hex/Java" 会把 \uXXXX / \UXXXXXXXX 都转为真实字符
        if CFStringTransform(ms, nil, "Any-Hex/Java" as CFString, true) {
            return ms as String
        }
        return s
    }
    // ---------- JSON Utilities ----------
    private static func toJSONString(_ any: Any, pretty: Bool, decodeUnicode: Bool) -> String? {
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []

        if let data = any as? Data,
           let obj = try? JSONSerialization.jsonObject(with: data),
           let out = try? JSONSerialization.data(withJSONObject: obj, options: options),
           let s = String(data: out, encoding: .utf8) {
            return decodeUnicode ? decodeUnicodeEscapes(s) : s
        }

        if let s = any as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.first == "{" || t.first == "[" {
                if let d = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: d),
                   let out = try? JSONSerialization.data(withJSONObject: obj, options: options),
                   let js = String(data: out, encoding: .utf8) {
                    return decodeUnicode ? decodeUnicodeEscapes(js) : js
                }
            }
            return nil
        }
        return nil
    }

    private static func tryJSONFromContainers(_ any: Any, pretty: Bool) -> String? {
        let options: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
        if let dict = any as? [AnyHashable: Any] {
            let m = Dictionary(uniqueKeysWithValues: dict.map { (k, v) in (String(describing: k), v) })
            if JSONSerialization.isValidJSONObject(m),
               let d = try? JSONSerialization.data(withJSONObject: m, options: options),
               let s = String(data: d, encoding: .utf8) {
                return decodeUnicodeEscapes(s)
            }
        }
        if let arr = any as? [Any],
           JSONSerialization.isValidJSONObject(arr),
           let d = try? JSONSerialization.data(withJSONObject: arr, options: options),
           let s = String(data: d, encoding: .utf8) {
            return decodeUnicodeEscapes(s)
        }
        return nil
    }
    // ---------- Object → JSON-ready（反射，防循环） ----------
    private static func toJSONStringFromObject(_ any: Any, pretty: Bool, maxDepth: Int) -> String? {
        var visited = Set<ObjectIdentifier>()
        let jsonReady = toJSONReady(any, depth: maxDepth, visited: &visited)
        guard JSONSerialization.isValidJSONObject(jsonReady) else { return nil }
        let opts: JSONSerialization.WritingOptions = pretty ? [.prettyPrinted] : []
        if let d = try? JSONSerialization.data(withJSONObject: jsonReady, options: opts),
           let s = String(data: d, encoding: .utf8) {
            return decodeUnicodeEscapes(s)
        }
        return nil
    }
    // ✅ 用 Mirror 正确解 Optional
    private static func unwrapOptional(_ value: Any) -> (isNil: Bool, unwrapped: Any?) {
        let m = Mirror(reflecting: value)
        guard m.displayStyle == .optional else { return (false, value) }
        if let child = m.children.first {
            return (false, child.value) // .some
        } else {
            return (true, nil)          // .none
        }
    }

    private static func toJSONReady(_ any: Any, depth: Int, visited: inout Set<ObjectIdentifier>) -> Any {
        if depth <= 0 { return "<depth-limit>" }

        // 1) Optional
        let (isNil, unwrapped) = unwrapOptional(any)
        if isNil { return NSNull() }
        let value = unwrapped ?? any

        // 2) 基本/可序列化类型直接返回
        switch value {
        case is NSNull:               return NSNull()
        case let x as String:         return x
        case let x as NSString:       return String(x)
        case let x as Bool:           return x
        case let x as Int:            return x
        case let x as Int8:           return x
        case let x as Int16:          return x
        case let x as Int32:          return x
        case let x as Int64:          return x
        case let x as UInt:           return x
        case let x as UInt8:          return x
        case let x as UInt16:         return x
        case let x as UInt32:         return x
        case let x as UInt64:         return x
        case let x as Float:          return x
        case let x as Double:         return x
        case let x as NSNumber:       return x
        case let x as Date:           return ISO8601DateFormatter().string(from: x)
        case let x as URL:            return x.absoluteString
        case let x as Data:           return ["<Data>": x.count] // 避免巨型 base64
        default: break
        }

        let mirror = Mirror(reflecting: value)
        // 3) Array / Set
        if mirror.displayStyle == .collection || mirror.displayStyle == .set {
            return mirror.children.map { toJSONReady($0.value, depth: depth - 1, visited: &visited) }
        }
        // 4) Dictionary（child 是 (key,value) 元组，这里稳妥拆解）
        if mirror.displayStyle == .dictionary {
            var dict: [String: Any] = [:]
            for child in mirror.children {
                // 优先尝试强转
                if let pair = child.value as? (AnyHashable, Any) {
                    dict[String(describing: pair.0)] = toJSONReady(pair.1, depth: depth - 1, visited: &visited)
                    continue
                }
                // 退而求其次：用反射拿到元组的两个 child
                let pm = Mirror(reflecting: child.value)
                let kv = pm.children.map { $0.value }
                let k = kv.indices.contains(0) ? kv[0] : "<key>"
                let v = kv.indices.contains(1) ? kv[1] : NSNull()
                dict[String(describing: k)] = toJSONReady(v, depth: depth - 1, visited: &visited)
            }
            return dict
        }
        // 5) Enum（记录类型、case、关联值）
        if mirror.displayStyle == .enum {
            var out: [String: Any] = ["_type": String(describing: type(of: value))]
            if let first = mirror.children.first {
                out["_case"] = first.label ?? "<case>"
                out["_value"] = toJSONReady(first.value, depth: depth - 1, visited: &visited)
            } else {
                out["_case"] = "<empty>"
            }
            return out
        }
        // 6) Class/Struct：采集属性；Class 做循环检测
        var props: [String: Any] = [:]
        if mirror.displayStyle == .class, let obj = value as AnyObject? {
            let oid = ObjectIdentifier(obj)
            if visited.contains(oid) { return ["<ref>": String(describing: type(of: value))] }
            visited.insert(oid); do { visited.remove(oid) }
        }

        var cur: Mirror? = mirror
        var depthNext = depth - 1
        while let m = cur, depthNext >= 0 {
            for c in m.children {
                if let name = c.label {
                    props[name] = toJSONReady(c.value, depth: depthNext, visited: &visited)
                }
            }
            cur = m.superclassMirror
            depthNext = depthNext - 1     // 防止超深的继承链
        }
        return ["_type": String(describing: type(of: value)), "_props": props]
    }
}
// MARK: - 全局函数（免前缀）
@inline(__always)
public func log(_ items: Any?...,
                level: JobsLog.Level = .plain,
                mode: JobsLog.Mode = .auto,
                prettyJSON: Bool = true,
                maxDepth: Int = 3,
                separator: String = " ",
                terminator: String = "\n",
                file: String = #file, line: Int = #line, function: String = #function) {
    JobsLog.log(items,
                level: level, mode: mode, prettyJSON: prettyJSON, maxDepth: maxDepth,
                separator: separator, terminator: terminator,
                file: file, line: line, function: function)
}
// MARK: - DEBUG 模式下才允许做的事
@inline(__always)
func debugOnly(_ work: @escaping @MainActor () -> Void) {
    #if DEBUG
    Task { @MainActor in work() }
    #endif
}
// MARK: - 主线程
@inline(__always)
func onMain(_ block: @escaping @MainActor () -> Void) {
    Task { @MainActor in
        block()
    }
}
// MARK: - 同步拿返回值
@discardableResult
func onMainSync<T>(_ work: () -> T) -> T {
    if Thread.isMainThread { return work() }
    var result: T!
    DispatchQueue.main.sync { result = work() }
    return result
}
// MARK: - 私有：蓝色占位图（1x1）
// 统一的纯色占位（1×1）；需要更大就改 size
func jobsSolidBlue(
    color: UIColor = .systemBlue,
    size: CGSize = .init(width: 1, height: 1),
    scale: CGFloat = 0
) -> UIImage {
    let fmt = UIGraphicsImageRendererFormat.default(); fmt.scale = scale
    return UIGraphicsImageRenderer(size: size, format: fmt).image { ctx in
        color.setFill()
        ctx.fill(CGRect(origin: .zero, size: size))
    }
}
// MARK: - NSTextAlignment 映射到 CATextLayerAlignmentMode
extension CATextLayerAlignmentMode {
    static func fromNSTextAlignment(_ a: NSTextAlignment) -> CATextLayerAlignmentMode {
        switch a {
        case .left: return .left
        case .right: return .right
        case .center: return .center
        case .justified: return .justified
        case .natural: return .natural
        @unknown default: return .natural
        }
    }
}
import CoreText

@inline(__always)
func jobsCTTextWidth(_ text: String, font: UIFont) -> CGFloat {
    let attr = [NSAttributedString.Key.font: font]
    let asr  = NSAttributedString(string: text, attributes: attr)
    let line = CTLineCreateWithAttributedString(asr)
    let w    = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    let s    = UIScreen.main.scale
    return ceil(w * s) / s   // 像素对齐
}
