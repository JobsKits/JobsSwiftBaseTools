//
//  TRAutoRefresh.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 11/1/25.
//
//  语言切换自动刷新引擎（无兼容分支）
//  依赖：Notification.Name.JobsLanguageDidChange、TRLang.bundleProvider()
//

import UIKit

public enum TRAutoRefresh {
    // MARK: - 线程本地标记（.tr 内部调用）
    public enum Marker {
        private static let threadKey = "jobs.tr.marker.key"
        /// .tr 调用尾部调用：把 key/table 放到当前线程词典里，然后原样返回翻译后的字符串
        @inline(__always)
        public static func pack(translated: String, key: String, table: String?) -> String {
            Thread.current.threadDictionary[threadKey] = Info(key: key, table: table)
            return translated
        }
        /// 由控件入口（UILabel/UIButton 等）“消费”最近一次的 Key；消费后即清空
        @inline(__always)
        static func consume() -> Info? {
            let dict = Thread.current.threadDictionary
            guard let info = dict[threadKey] as? Info else { return nil }
            dict.removeObject(forKey: threadKey)
            return info
        }

        public struct Info {
            public let key: String
            public let table: String?
        }
    }
    // MARK: - 注册表
    private final class Entry {
        weak var target: AnyObject?
        let key: String
        let table: String?
        let apply: (AnyObject, String) -> Void

        init(target: AnyObject, key: String, table: String?, apply: @escaping (AnyObject, String) -> Void) {
            self.target = target
            self.key = key
            self.table = table
            self.apply = apply
        }
    }

    private static var entries: [Entry] = []
    private static let lock = NSLock()
    private static var isObserving = false
    private static var token: NSObjectProtocol?
    // MARK: - 注册与刷新
    @inline(__always)
    private static func ensureObserver() {
        guard !isObserving else { return }
        isObserving = true
        token = NotificationCenter.default.addObserver(
            forName: .JobsLanguageDidChange, object: nil, queue: .main
        ) { _ in
            TRAutoRefresh.refreshAll()
        }
    }
    /// 把任意目标对象与 key 绑定；语言变化时会把 key.tr 再次设置回去
    public static func register<T: AnyObject>(_ target: T,
                                             key: String,
                                             table: String? = nil,
                                             apply: @escaping (T, String) -> Void) {
        ensureObserver()
        let entry = Entry(target: target, key: key, table: table) { obj, text in
            if let t = obj as? T {
                apply(t, text)
            }
        }
        lock.lock(); entries.append(entry); lock.unlock()
    }
    /// 主线程刷新全部已注册控件
    private static var _isRefreshing = false
    public static func refreshAll() {
        precondition(Thread.isMainThread, "must be on main")
        guard !_isRefreshing else { return }     // 防 re-entrancy
        _isRefreshing = true
        // 不需要 NSLock（既然强制在主线程）
        entries = entries.filter { $0.target != nil }
        let snapshot = entries
        let bundle = TRLang.bundle()

        for e in snapshot {
            guard let obj = e.target else { continue }
            let translated = NSLocalizedString(e.key, tableName: e.table, bundle: bundle, value: e.key, comment: "")
            e.apply(obj, translated)
        }
        _isRefreshing = false
    }
}
// MARK: - 常用控件：一行接入
public extension UILabel {
    /// 直接把 ".tr" 的结果丢进来即可；会自动从线程标记里拿 key 并注册刷新
    @discardableResult
    func tr_setText(_ string: String) -> Self {
        let info = TRAutoRefresh.Marker.consume()
        self.text = string
        if let info { TRAutoRefresh.register(self, key: info.key, table: info.table) { view, text in
            view.text = text
        }}
        return self
    }
    /// placeholder-like 文本（有些人把 UILabel 当占位符）
    @discardableResult
    func tr_setAttributedText(_ attr: NSAttributedString) -> Self {
        // 富文本不做自动注册（如需支持，可自行封装 key → 富文本工厂）
        self.attributedText = attr
        _ = TRAutoRefresh.Marker.consume() // 清掉线程标记，避免漏挂到下一个 setter
        return self
    }
}

public extension UIButton {
    @discardableResult
    func tr_setTitle(_ string: String, for state: UIControl.State) -> Self {
        let info = TRAutoRefresh.Marker.consume()
        self.setTitle(string, for: state)
        if let info {
            TRAutoRefresh.register(self, key: info.key, table: info.table) { btn, text in
                btn.setTitle(text, for: state)
            }
        }
        return self
    }
}

public extension UITextField {
    @discardableResult
    func tr_setPlaceholder(_ string: String) -> Self {
        let info = TRAutoRefresh.Marker.consume()
        self.placeholder = string
        if let info {
            TRAutoRefresh.register(self, key: info.key, table: info.table) { tf, text in
                tf.placeholder = text
            }
        }
        return self
    }

    @discardableResult
    func tr_setText(_ string: String) -> Self {
        let info = TRAutoRefresh.Marker.consume()
        self.text = string
        if let info {
            TRAutoRefresh.register(self, key: info.key, table: info.table) { tf, text in
                tf.text = text
            }
        }
        return self
    }
}

public extension UIBarButtonItem {
    @discardableResult
    func tr_setTitle(_ string: String) -> Self {
        let info = TRAutoRefresh.Marker.consume()
        self.title = string
        if let info {
            TRAutoRefresh.register(self, key: info.key, table: info.table) { item, text in
                item.title = text
            }
        }
        return self
    }
}
