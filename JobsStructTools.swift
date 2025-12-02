//
//  JobsStructTools.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 12/1/25.
//
import JobsSwiftBaseDefines
/// 一些用结构体定义的小工具
public struct JobsValidators {
    // MARK: - 非空验证
    static func nonEmpty(_ s: String) -> Bool {
        !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    // MARK: - 数值范围验证器
    static func decimal(min: Double? = nil, max: Double? = nil) -> (String) -> Bool {
        return { s in
            guard let v = Double(s) else { return false }
            if let min = min, v < min { return false }
            if let max = max, v > max { return false }
            return true
        }
    }
    // MARK: - 手机号验证（中国大陆）
    static func phoneCN() -> (String) -> Bool {
        return { s in
            // 去空格后的纯数字长度 11
            let digits = s.filter(\.isNumber)
            return digits.count == 11
        }
    }
}
/**
     let id18 = "510105199307315321"                 // 18位示例（应有效）
     let id15 = "130503670401001"                     // 15位经典示例
     do {
      let normalizedFrom18 = try CNID.validate(id18)      // 返回18位本身
      let normalizedFrom15 = try CNID.validate(id15)      // 自动转18位
      print("18 -> \(normalizedFrom18)")
      print("15 -> \(normalizedFrom15)")                  // 预期：13050319670401001X
     } catch { print("无效：\(error)") }

     print("isValid(18):", CNID.isValid(id18))
     print("isValid(15):", CNID.isValid(id15))
 */
// MARK: - 中国大陆居民身份证号码校验
public struct CNID {
    private static let re18 = try! NSRegularExpression(pattern: #"^\d{17}[\dX]$"#)
    private static let re15 = try! NSRegularExpression(pattern: #"^\d{15}$"#)
    private static let weights = [7,9,10,5,8,4,2,1,6,3,7,9,10,5,8,4,2]
    private static let map: [Int: Character] = [0:"1",1:"0",2:"X",3:"9",4:"8",5:"7",6:"6",7:"5",8:"4",9:"3",10:"2"]
    /// 快速校验：自动兼容 15/18 位
    static func isValid(_ raw: String) -> Bool { (try? validate(raw)) != nil }
    /// 严格校验：非法抛错。总是返回“归一化后的18位证号”
    @discardableResult
    static func validate(_ raw: String, centuryHintFor15: Int = 19) throws -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if match(re18, s) { try validate18(s); return s }
        if match(re15, s) {
            let v18 = try convert15to18(s, centuryHint: centuryHintFor15)
            try validate18(v18)
            return v18
        };throw CNIDError.format
    }
    /// 将 15 位转换为 18 位（默认世纪 “19”）
    static func convert15to18(_ id15: String, centuryHint: Int = 19) throws -> String {
        guard match(re15, id15) else { throw CNIDError.format }
        let area = String(id15.prefix(6))
        let yymmdd = String(id15[id15.index(id15.startIndex, offsetBy:6)..<id15.index(id15.startIndex, offsetBy:12)])
        let seq = String(id15.suffix(3))
        /// 15位默认表示 1900-1999 年出生（个别极边缘例外可通过 centuryHint 覆写为 20）
        let yearPrefix = String(centuryHint)
        let yyyyMMdd = yearPrefix + yymmdd
        let body17 = area + yyyyMMdd + seq
        let check = checksumFor(body17)
        return body17 + String(check)
    }

    private static func match(_ re: NSRegularExpression, _ s: String) -> Bool {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    private static func validate18(_ id: String) throws {
        guard match(re18, id) else { throw CNIDError.format }
        // 出生日期
        let y = Int(id[Range(NSRange(location: 6, length: 4), in: id)!])!
        let m = Int(id[Range(NSRange(location:10, length:2), in: id)!])!
        let d = Int(id[Range(NSRange(location:12, length:2), in: id)!])!
        var comps = DateComponents(); comps.year = y; comps.month = m; comps.day = d
        let cal = Calendar(identifier: .gregorian)
        guard let birth = cal.date(from: comps) else { throw CNIDError.birthDate }
        let minDate = cal.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        let maxDate = Date()
        guard (minDate ... maxDate).contains(birth) else { throw CNIDError.birthDate }
        // 顺序码≠"000"
        let seq = id[Range(NSRange(location:14, length:3), in: id)!]
        guard seq != "000" else { throw CNIDError.sequence }
        // 校验位
        let body17 = String(id.prefix(17))
        let expected = checksumFor(body17)
        guard id.last! == expected else { throw CNIDError.checksum }
    }

    private static func checksumFor(_ body17: String) -> Character {
        var sum = 0
        for (i, ch) in body17.enumerated() {
            sum += Int(ch.asciiValue! - Character("0").asciiValue!) * weights[i]
        }
        let r = sum % 11
        return map[r]!
    }
}
// MARK: - 制造非波拉契数列
struct FibonacciSequence: Sequence {
    let count: Int
    func makeIterator() -> AnyIterator<Int> {
        var i = 0
        var a = 0
        var b = 1
        return AnyIterator {
            guard i < self.count else { return nil }
            defer {
                let next = a + b
                a = b
                b = next
                i += 1
            };return a
        }
    }
}
// MARK: - 通用于 UITableViewCell 和 UICollectionViewCell 的模型组件
public struct JobsCellConfig {
    public let title: JobsText?
    public let detail: JobsText?
    public let image: UIImage?
    public let data: Any?

    public init(title: JobsText? = nil,
                detail: JobsText? = nil,
                image: UIImage? = nil,
                data: Any? = nil) {
        self.title = title
        self.detail = detail
        self.image = image
        self.data = data
    }
}
