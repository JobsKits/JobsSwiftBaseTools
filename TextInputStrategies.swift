//
//  TextInputStrategies.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 9/29/25.
//

import Foundation

public enum TextFormatStrategy {
    /// 直接原样（可与其他策略组合使用时置于最后）
    case identity

    /// 去除所有空格
    case trimSpaces

    /// 全部小写 / 大写
    case lowercased
    case uppercased

    /// 仅保留数字
    case digitsOnly

    /// 保留数字与小数点，限制小数位数（如 .decimal(2)）
    case decimal(Int)

    /// 中国手机号：去非数字，最多 11 位，按 3-4-4 自动分组显示（内部存原始 digits）
    case phoneCNGrouped

    /// 银行卡分组（4-4-4-...）
    case bankCardGrouped

    /// 自定义：把 (String) -> String 直接包装成策略
    case custom((_ s: String) -> String)

    // 组合：按顺序依次应用
    public static func chain(_ strategies: [TextFormatStrategy]) -> (String) -> String {
        return { input in
            strategies.reduce(input) { acc, s in s.apply(acc) }
        }
    }

    public func apply(_ s: String) -> String {
        switch self {
        case .identity:
            return s
        case .trimSpaces:
            return s.replacingOccurrences(of: " ", with: "")
        case .lowercased:
            return s.lowercased()
        case .uppercased:
            return s.uppercased()
        case .digitsOnly:
            return s.filter { $0.isNumber }
        case .decimal(let scale):
            // 仅保留一处小数点 + 限制小数位数
            var filtered = s.filter { $0.isNumber || $0 == "." }
            // 合并多余小数点
            if let firstDot = filtered.firstIndex(of: ".") {
                let after = filtered.index(after: firstDot)
                let tail = filtered[after...].replacingOccurrences(of: ".", with: "")
                filtered = String(filtered[..<after]) + tail
            }
            if scale >= 0, let dot = filtered.firstIndex(of: ".") {
                let end = filtered.index(dot, offsetBy: scale + 1, limitedBy: filtered.endIndex) ?? filtered.endIndex
                filtered = String(filtered[..<end])
            }
            return filtered
        case .phoneCNGrouped:
            // 展示分组：3-4-4；内部可以在回写 VM 时去空格
            let digits = s.filter { $0.isNumber }.prefix(11)
            let raw = String(digits)
            switch raw.count {
            case 0...3: return raw
            case 4...7:
                let a = raw.prefix(3)
                let b = raw.dropFirst(3)
                return "\(a) \(b)"
            default:
                let a = raw.prefix(3)
                let b = raw.dropFirst(3).prefix(4)
                let c = raw.dropFirst(7)
                return "\(a) \(b) \(c)"
            }
        case .bankCardGrouped:
            let digits = s.filter { $0.isNumber }
            return stride(from: 0, to: digits.count, by: 4)
                .map { i -> String in
                    let start = digits.index(digits.startIndex, offsetBy: i)
                    let end = digits.index(start, offsetBy: 4, limitedBy: digits.endIndex) ?? digits.endIndex
                    return String(digits[start..<end])
                }
                .joined(separator: " ")
        case .custom(let f):
            return f(s)
        }
    }
}

public enum TextValidateStrategy {
    case alwaysTrue
    case nonEmpty
    case minLength(Int)
    case email
    case phoneCN   // 纯 11 位数字
    case bankCard(min: Int = 12) // 最低长度校验
    case decimal(maxScale: Int)
    case regex(NSRegularExpression)

    /// 组合校验：全部为 true 才通过
    public static func all(_ strategies: [TextValidateStrategy]) -> (String) -> Bool {
        return { s in strategies.allSatisfy { $0.test(s) } }
    }

    public func test(_ s: String) -> Bool {
        switch self {
        case .alwaysTrue:
            return true
        case .nonEmpty:
            return !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .minLength(let n):
            return s.count >= n
        case .email:
            // 简洁校验（生产建议换更严格正则）
            let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
            return s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        case .phoneCN:
            let digits = s.filter { $0.isNumber }
            return digits.count == 11
        case .bankCard(let min):
            let digits = s.filter { $0.isNumber }
            return digits.count >= min
        case .decimal(let maxScale):
            if let dot = s.firstIndex(of: ".") {
                let scale = s.distance(from: dot, to: s.endIndex) - 1
                return scale >= 0 && scale <= maxScale
            }
            return true
        case .regex(let re):
            let range = NSRange(location: 0, length: (s as NSString).length)
            return re.firstMatch(in: s, options: [], range: range) != nil
        }
    }
}

/// 预置工厂：一站式拿格式化 + 校验闭包
public struct TextInputStrategyFactory {
    public struct PhoneCN {
        /// 展示：3-4-4 分组；校验：11 位
        public static var formatter: (String) -> String {
            TextFormatStrategy.chain([.trimSpaces, .phoneCNGrouped])
        }
        public static var validator: (String) -> Bool {
            TextValidateStrategy.all([.phoneCN])
        }
    }

    public struct BankCard {
        public static var formatter: (String) -> String {
            TextFormatStrategy.chain([.trimSpaces, .bankCardGrouped])
        }
        public static var validator: (String) -> Bool {
            TextValidateStrategy.all([.bankCard(min: 12)])
        }
    }

    public struct Email {
        public static var formatter: (String) -> String {
            TextFormatStrategy.chain([.trimSpaces, .lowercased])
        }
        public static var validator: (String) -> Bool {
            TextValidateStrategy.all([.email])
        }
    }

    public struct Digits {
        public static func formatter(maxLength: Int? = nil) -> (String) -> String {
            let base = TextFormatStrategy.digitsOnly.apply
            if let m = maxLength { return { String(base($0).prefix(m)) } }
            return base
        }
        public static func validator(minLength: Int = 1) -> (String) -> Bool {
            { s in s.filter(\.isNumber).count >= minLength }
        }
    }

    public struct Decimal {
        public static func formatter(scale: Int) -> (String) -> String {
            TextFormatStrategy.decimal(scale).apply
        }
        public static func validator(maxScale: Int) -> (String) -> Bool {
            TextValidateStrategy.decimal(maxScale: maxScale).test
        }
    }
}
