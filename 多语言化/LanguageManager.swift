//
//  LanguageManager.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 11/1/25.
//

import Foundation

public extension Notification.Name {
    /// 全局：语言切换完成
    static let JobsLanguageDidChange = Notification.Name("JobsLanguageDidChange")
}

public final class LanguageManager {
    public static let shared = LanguageManager()

    private let userDefaultsKey = "Jobs.LanguageCode"
    public private(set) var currentLanguageCode: String

    public init() {
        // 读持久化；默认跟随系统（可按需改）
        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey) {
            currentLanguageCode = saved
        } else {
            currentLanguageCode = Locale.preferredLanguages.first ?? "en"
        }
    }
    /// 动态 Bundle：每次按当前 code 解析路径
    public var localizedBundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: currentLanguageCode, ofType: "lproj"),
            let b = Bundle(path: path)
        else {
            return .main
        }
        return b
    }
    /// 切换语言：更新 code → 持久化 → 发通知
    public func switchTo(_ code: String) {
        guard code != currentLanguageCode else { return }
        currentLanguageCode = code
        UserDefaults.standard.set(code, forKey: userDefaultsKey)
        NotificationCenter.default.post(name: .JobsLanguageDidChange, object: nil)
    }
}
