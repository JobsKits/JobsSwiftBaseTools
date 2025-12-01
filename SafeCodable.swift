//
//  SafeCodable.swift
//  产线级：默认值协议 + 可配置宽松解码 + Date/URL 支持 + 告警上报 + Optional 版本
//

import Foundation

// ================================== SafeDefault：类型级默认值 ==================================

public protocol SafeDefault {
    static var defaultValue: Self { get }
}

extension String: SafeDefault { public static var defaultValue: String { "" } }
extension Int: SafeDefault { public static var defaultValue: Int { 0 } }
extension Double: SafeDefault { public static var defaultValue: Double { 0 } }
extension Float: SafeDefault { public static var defaultValue: Float { 0 } }
extension Bool: SafeDefault { public static var defaultValue: Bool { false } }
extension Decimal: SafeDefault { public static var defaultValue: Decimal { 0 } }
extension Date: SafeDefault { public static var defaultValue: Date { .distantPast } }
// about:blank 稳定可解析的占位 URL
extension URL: SafeDefault { public static var defaultValue: URL { URL(string: "about:blank")! } }

// ================================== 事件上报中心 ==================================

public enum SafeCodableEvent {
    /// 发生了宽松转换
    case coerced(from: String, to: String, codingPath: [String], rawSample: String?)
    /// 落到默认值（非 Optional）
    case defaulted(expected: String, codingPath: [String], reason: String)
    /// 彻底失败（Optional → nil 等）
    case failed(expected: String, codingPath: [String], reason: String)
}

public protocol SafeCodableReporting: AnyObject {
    func report(_ event: SafeCodableEvent)
}

public final class SafeCodableReportCenter {
    public static var shared: SafeCodableReporting?
    private init() {}
}

// ================================== 配置（全局 + 轻覆写） ==================================

public struct SafeCodableConfig {
    // 字符串处理
    public var trimStrings: Bool = true

    // 类型间宽松转换
    public var allowStringToNumber: Bool = true
    public var allowStringToBool: Bool = true
    public var allowNumberToString: Bool = true
    public var allowNumberToBool: Bool = true
    public var allowBoolToNumber: Bool = true
    public var allowBoolToString: Bool = true

    // Date 解析
    public var allowISO8601Date: Bool = true
    public var allowCustomDateFormats: Bool = true
    public var customDateFormatters: [DateFormatter] = []  // 可注入多种格式
    public var allowUnixTimestampSeconds: Bool = true
    public var allowUnixTimestampMilliseconds: Bool = true
    public var allowStringifiedTimestamp: Bool = true

    // URL 解析
    public var allowURLFromString: Bool = true
    /// 空字符串当作“无值”（非 Optional 时会落默认值）
    public var treatEmptyStringAsNilForURL: Bool = true

    // 布尔字面量
    public var boolTrueLiterals: Set<String>  = ["true", "yes", "y", "on", "1"]
    public var boolFalseLiterals: Set<String> = ["false", "no", "n", "off", "0"]

    // 上报
    public var reporter: SafeCodableReporting? {
        get { SafeCodableReportCenter.shared }
        set { SafeCodableReportCenter.shared = newValue }
    }

    public init() {}

    /// 全局共享配置（解码时读取）
    public static var shared = SafeCodableConfig()
}

// ================================== 工具：编码路径 & 报告 ==================================

@inline(__always)
private func codingPathStrings(_ decoder: Decoder) -> [String] {
    decoder.codingPath.map { $0.stringValue }
}

@inline(__always)
private func report(_ event: SafeCodableEvent) {
    SafeCodableReportCenter.shared?.report(event)
}

// 小工具：共享 ISO8601 格式器（减少分配）
private enum _DateParsers {
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        // 默认行为已够用，如需要微调（.withFractionalSeconds）可在这里配置
        return f
    }()
}

// ================================== SafeCodable：非 Optional 包装器 ==================================

@propertyWrapper
public struct SafeCodable<T: Codable & SafeDefault>: Codable {
    public var wrappedValue: T

    // 轻覆写项（默认解码期不使用，见下方说明）
    private let localTreatEmptyStringAsNilForURL: Bool?

    public init(wrappedValue: T = T.defaultValue,
                treatEmptyStringAsNilForURL: Bool? = nil) {
        self.wrappedValue = wrappedValue
        self.localTreatEmptyStringAsNilForURL = treatEmptyStringAsNilForURL
    }

    public init(from decoder: Decoder) throws {
        let cfg = SafeCodableConfig.shared
        let codingPath = codingPathStrings(decoder)
        let container = try decoder.singleValueContainer()

        // 用局部变量承接结果，最后统一赋值，避免“提前 return 未初始化所有存储属性”
        let value: T

        if container.decodeNil() {
            value = T.defaultValue
            report(.defaulted(expected: "\(T.self)", codingPath: codingPath, reason: "null"))
        } else if let v = try? container.decode(T.self) {
            value = v
        } else if let v: T = coerce(
            T.self,
            from: container,
            cfg: cfg,
            codingPath: codingPath,
            // 解码阶段不读取 self；按全局策略处理
            treatEmptyURLNil: cfg.treatEmptyStringAsNilForURL
        ) {
            value = v
        } else {
            value = T.defaultValue
            report(.defaulted(expected: "\(T.self)", codingPath: codingPath, reason: "coercion-failed"))
        }

        // 统一在最后初始化所有存储属性
        self.wrappedValue = value
        // 解码时 wrapper 的构造参数不会被传入，这里置空仅为满足初始化完整性
        self.localTreatEmptyStringAsNilForURL = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(wrappedValue)
    }
}

// ================================== SafeCodableOptional：Optional 版本 ==================================

@propertyWrapper
public struct SafeCodableOptional<T: Codable & SafeDefault>: Codable {
    public var wrappedValue: T?

    private let localTreatEmptyStringAsNilForURL: Bool?

    public init(wrappedValue: T? = nil,
                treatEmptyStringAsNilForURL: Bool? = nil) {
        self.wrappedValue = wrappedValue
        self.localTreatEmptyStringAsNilForURL = treatEmptyStringAsNilForURL
    }

    public init(from decoder: Decoder) throws {
        let cfg = SafeCodableConfig.shared
        let codingPath = codingPathStrings(decoder)
        let container = try decoder.singleValueContainer()

        // 收敛到局部变量
        let value: T?

        if container.decodeNil() {
            value = nil    // Optional 碰到 null → nil，不上报以减少噪音
        } else if let v = try? container.decode(T.self) {
            value = v
        } else if let v: T = coerce(
            T.self,
            from: container,
            cfg: cfg,
            codingPath: codingPath,
            treatEmptyURLNil: cfg.treatEmptyStringAsNilForURL
        ) {
            value = v
        } else {
            value = nil
            report(.failed(expected: "\(T?.self)", codingPath: codingPath, reason: "coercion-failed"))
        }

        self.wrappedValue = value
        self.localTreatEmptyStringAsNilForURL = nil
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        if let v = wrappedValue {
            try c.encode(v)
        } else {
            try c.encodeNil()
        }
    }
}

// ================================== 核心：宽松转换实现 ==================================

private func coerce<T: Codable>(
    _ type: T.Type,
    from container: SingleValueDecodingContainer,
    cfg: SafeCodableConfig,
    codingPath: [String],
    treatEmptyURLNil: Bool
) -> T? where T: SafeDefault {

    // —— 优先尝试字符串 ——
    if var s = try? container.decode(String.self) {
        if cfg.trimStrings {
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let v: T = fromString(s, cfg: cfg, codingPath: codingPath, treatEmptyURLNil: treatEmptyURLNil) {
            return v
        }
    }

    // —— 再尝试数值/布尔 ——
    if let i = try? container.decode(Int.self),
       let v: T = fromInt(i, cfg: cfg, codingPath: codingPath) { return v }

    if let d = try? container.decode(Double.self),
       let v: T = fromDouble(d, cfg: cfg, codingPath: codingPath) { return v }

    if let b = try? container.decode(Bool.self),
       let v: T = fromBool(b, cfg: cfg, codingPath: codingPath) { return v }

    return nil
}

private func fromString<T: SafeDefault & Codable>(
    _ s: String,
    cfg: SafeCodableConfig,
    codingPath: [String],
    treatEmptyURLNil: Bool
) -> T? {

    switch T.self {
    case is String.Type:
        report(.coerced(from: "String", to: "\(T.self)", codingPath: codingPath, rawSample: s))
        return (s as! T)

    case is Int.Type where cfg.allowStringToNumber:
        if let v = Int(s) {
            report(.coerced(from: "String", to: "Int", codingPath: codingPath, rawSample: s))
            return (v as! T)
        }

    case is Double.Type where cfg.allowStringToNumber:
        if let v = Double(s) {
            report(.coerced(from: "String", to: "Double", codingPath: codingPath, rawSample: s))
            return (v as! T)
        }

    case is Float.Type where cfg.allowStringToNumber:
        if let v = Float(s) {
            report(.coerced(from: "String", to: "Float", codingPath: codingPath, rawSample: s))
            return (v as! T)
        }

    case is Decimal.Type where cfg.allowStringToNumber:
        if let v = Decimal(string: s) {
            report(.coerced(from: "String", to: "Decimal", codingPath: codingPath, rawSample: s))
            return (v as! T)
        }

    case is Bool.Type where cfg.allowStringToBool:
        let lowered = s.lowercased()
        if cfg.boolTrueLiterals.contains(lowered) {
            report(.coerced(from: "String", to: "Bool(true)", codingPath: codingPath, rawSample: s))
            return (true as! T)
        }
        if cfg.boolFalseLiterals.contains(lowered) {
            report(.coerced(from: "String", to: "Bool(false)", codingPath: codingPath, rawSample: s))
            return (false as! T)
        }
        // 数字串 → Bool
        if let i = Int(s) {
            report(.coerced(from: "String(number)", to: "Bool(\(i != 0))", codingPath: codingPath, rawSample: s))
            return ((i != 0) as! T)
        }
        if let d = Double(s) {
            report(.coerced(from: "String(number)", to: "Bool(\(d != 0))", codingPath: codingPath, rawSample: s))
            return ((d != 0) as! T)
        }

    case is Date.Type:
        // 1) ISO8601
        if cfg.allowISO8601Date {
            if let v = _DateParsers.iso8601.date(from: s) {
                report(.coerced(from: "String(ISO8601)", to: "Date", codingPath: codingPath, rawSample: s))
                return (v as! T)
            }
        }
        // 2) 自定义格式
        if cfg.allowCustomDateFormats {
            for fmt in cfg.customDateFormatters {
                if let v = fmt.date(from: s) {
                    report(.coerced(from: "String(DateFormatter:\(fmt.dateFormat ?? ""))", to: "Date", codingPath: codingPath, rawSample: s))
                    return (v as! T)
                }
            }
        }
        // 3) 字符串数字时间戳
        if cfg.allowStringifiedTimestamp, let ts = Double(s) {
            if let v: T = fromDouble(ts, cfg: cfg, codingPath: codingPath) { return v }
        }

    case is URL.Type where cfg.allowURLFromString:
        if s.isEmpty, treatEmptyURLNil {
            // Optional 包装器会保留为 nil；非 Optional 由上层落默认值
            return nil
        }
        if let url = URL(string: s) {
            report(.coerced(from: "String", to: "URL", codingPath: codingPath, rawSample: s))
            return (url as! T)
        }

    default:
        break
    }
    return nil
}

private func fromInt<T: SafeDefault & Codable>(
    _ i: Int,
    cfg: SafeCodableConfig,
    codingPath: [String]
) -> T? {
    switch T.self {
    case is String.Type where cfg.allowNumberToString:
        report(.coerced(from: "Int", to: "String", codingPath: codingPath, rawSample: "\(i)"))
        return (String(i) as! T)
    case is Int.Type:
        return (i as! T)
    case is Double.Type:
        return (Double(i) as! T)
    case is Float.Type:
        return (Float(i) as! T)
    case is Decimal.Type:
        return (Decimal(i) as! T)
    case is Bool.Type where cfg.allowNumberToBool:
        report(.coerced(from: "Int", to: "Bool(\(i != 0))", codingPath: codingPath, rawSample: "\(i)"))
        return ((i != 0) as! T)
    case is Date.Type:
        if cfg.allowUnixTimestampSeconds {
            let v = Date(timeIntervalSince1970: TimeInterval(i))
            report(.coerced(from: "Int(timestamp_sec)", to: "Date", codingPath: codingPath, rawSample: "\(i)"))
            return (v as! T)
        }
    default:
        break
    }
    return nil
}

private func fromDouble<T: SafeDefault & Codable>(
    _ d: Double,
    cfg: SafeCodableConfig,
    codingPath: [String]
) -> T? {
    switch T.self {
    case is String.Type where cfg.allowNumberToString:
        report(.coerced(from: "Double", to: "String", codingPath: codingPath, rawSample: "\(d)"))
        return (String(d) as! T)
    case is Int.Type:
        return (Int(d) as! T)
    case is Double.Type:
        return (d as! T)
    case is Float.Type:
        return (Float(d) as! T)
    case is Decimal.Type:
        return (Decimal(d) as! T)
    case is Bool.Type where cfg.allowNumberToBool:
        report(.coerced(from: "Double", to: "Bool(\(d != 0))", codingPath: codingPath, rawSample: "\(d)"))
        return ((d != 0) as! T)
    case is Date.Type:
        // 识别秒/毫秒
        if cfg.allowUnixTimestampMilliseconds, d >= 1_000_000_000_000 {
            let v = Date(timeIntervalSince1970: d / 1000.0)
            report(.coerced(from: "Double(timestamp_ms)", to: "Date", codingPath: codingPath, rawSample: "\(d)"))
            return (v as! T)
        }
        if cfg.allowUnixTimestampSeconds {
            let v = Date(timeIntervalSince1970: d)
            report(.coerced(from: "Double(timestamp_sec)", to: "Date", codingPath: codingPath, rawSample: "\(d)"))
            return (v as! T)
        }
    default:
        break
    }
    return nil
}

private func fromBool<T: SafeDefault & Codable>(
    _ b: Bool,
    cfg: SafeCodableConfig,
    codingPath: [String]
) -> T? {
    switch T.self {
    case is String.Type where cfg.allowBoolToString:
        report(.coerced(from: "Bool", to: "String", codingPath: codingPath, rawSample: "\(b)"))
        return ((b ? "true" : "false") as! T)
    case is Int.Type where cfg.allowBoolToNumber:
        return ((b ? 1 : 0) as! T)
    case is Double.Type where cfg.allowBoolToNumber:
        return ((b ? 1.0 : 0.0) as! T)
    case is Float.Type where cfg.allowBoolToNumber:
        return ((b ? 1.0 : 0.0) as! T)
    case is Decimal.Type where cfg.allowBoolToNumber:
        return (Decimal(b ? 1 : 0) as! T)
    case is Bool.Type:
        return (b as! T)
    default:
        break
    }
    return nil
}

/**
     import Foundation
     // 1) 启动时全局配置
     enum SafeCodableBootstrap {
         static func configure() {
             var fmt = DateFormatter()
             fmt.locale = Locale(identifier: "en_US_POSIX")
             fmt.timeZone = TimeZone(secondsFromGMT: 0)
             fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

             SafeCodableConfig.shared.customDateFormatters = [fmt]
             SafeCodableConfig.shared.treatEmptyStringAsNilForURL = true

             SafeCodableReportCenter.shared = ConsoleReporter()
         }
         // 控制台上报器（也可接入你自己的日志系统）
         final class ConsoleReporter: SafeCodableReporting {
             func report(_ event: SafeCodableEvent) {
                 switch event {
                 case let .coerced(from, to, path, raw):
                     print("➡️ coerced \(path.joined(separator: ".")) \(from) -> \(to) raw=\(raw ?? "nil")")
                 case let .defaulted(expected, path, reason):
                     print("⚠️ defaulted \(path.joined(separator: ".")) to \(expected) because \(reason)")
                 case let .failed(expected, path, reason):
                     print("❌ failed \(path.joined(separator: ".")) expected \(expected): \(reason)")
                 }
             }
         }
     }
     // 2) 你的模型
     struct User: Codable {
         @SafeCodable var id: Int
         @SafeCodable var name: String
         @SafeCodable var vip: Bool
         @SafeCodable var score: Double
         @SafeCodable var createdAt: Date
         @SafeCodable var homepage: URL
         @SafeCodableOptional var avatarURL: URL?
     }
     // 3) 演示解码（放到你需要的地方调用）
     func demoDecode() {
         let json = #"""
         {
           "id": "42",
           "name": 777,
           "vip": "true",
           "score": "3.14",
           "createdAt": "2024-08-20 10:00:00",
           "homepage": "",
           "avatarURL": "https://a.b/c.png"
         }
         """#.data(using: .utf8)!

         do {
             let u = try JSONDecoder().decode(User.self, from: json)
             print("✅ decoded user:", u)
         } catch {
             print("❌ decode error:", error)
         }
     }
 */
