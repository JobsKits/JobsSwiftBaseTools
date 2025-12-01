//
//  JobsToast.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/4/25.
//

import UIKit
import SnapKit
// ================================== Toast ==================================
@MainActor
public final class JobsToast: UIView {
    public typealias Completion = () -> Void
    // ✅ 用 UInt8 做关联 key，避免字符串
    private static var currentToastKey: UInt8 = 0
    // 供懒加载按钮的点按回调占位（由 show(...) 注入）
    private var tapHandler: ((UIButton) -> Void)?
    // ✅ 懒加载按钮，使用已有链式 API
    private lazy var contentButton: UIButton = {
        UIButton(type: .system)
            .byNormalBgColor(.clear)
            .byTitle(" ", for: .normal) // 占位；真正文案在 show/链式里设
            .byTitleColor(.white, for: .normal)
            .byTitleFont(.systemFont(ofSize: 15, weight: .medium))
            .byContentEdgeInsets(UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16))
            .onTap { [weak self] sender in
                guard let self else { return }
                self.tapHandler?(sender)
            }
            .byAddTo(self) { make in
                make.edges.equalToSuperview()
            }
    }()

    private var completion: Completion?
    // MARK: - 配置：支持时长、边距、偏移、圆角、背景色等链式
    public struct Config {
        public var duration: TimeInterval = 1.0
        public var bottomOffset: CGFloat = 120
        public var horizontalPadding: CGFloat = 16
        public var verticalPadding: CGFloat = 10
        public var cornerRadius: CGFloat = 10
        public var backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.85)

        public init() {}
        // MARK: - 链式配置
        @discardableResult public func byDuration(_ value: TimeInterval) -> Self {
            var cfg = self; cfg.duration = value; return cfg
        }
        @discardableResult public func byBottomOffset(_ value: CGFloat) -> Self {
            var cfg = self; cfg.bottomOffset = value; return cfg
        }
        @discardableResult public func byHorizontalPadding(_ value: CGFloat) -> Self {
            var cfg = self; cfg.horizontalPadding = value; return cfg
        }
        @discardableResult public func byVerticalPadding(_ value: CGFloat) -> Self {
            var cfg = self; cfg.verticalPadding = value; return cfg
        }
        @discardableResult public func byCornerRadius(_ value: CGFloat) -> Self {
            var cfg = self; cfg.cornerRadius = value; return cfg
        }
        @discardableResult public func byBgColor(_ color: UIColor) -> Self {
            var cfg = self; cfg.backgroundColor = color; return cfg
        }
    }
}
// MARK: - JobsToast 自身的链式扩展
public extension JobsToast {
    /// 链式：设置完成回调
    @discardableResult
    func byCompletion(_ block: Completion?) -> Self {
        self.completion = block
        return self
    }
    /// 链式：设置点击回调
    @discardableResult
    func byTap(_ handler: ((UIButton) -> Void)?) -> Self {
        self.tapHandler = handler
        return self
    }
    /// 链式：设置显示文本
    @discardableResult
    func byText(_ text: String) -> Self {
        _ = contentButton
        contentButton.byTitle(text, for: .normal)
        return self
    }
    /// 链式：应用样式配置（背景色、圆角、padding）
    @discardableResult
    func byApply(_ config: Config) -> Self {
        // 容器外观
        backgroundColor = config.backgroundColor
        layer.cornerRadius = config.cornerRadius
        layer.masksToBounds = true
        // 内容内边距
        _ = contentButton
        contentButton.byContentEdgeInsets(UIEdgeInsets(
            top: config.verticalPadding,
            left: config.horizontalPadding,
            bottom: config.verticalPadding,
            right: config.horizontalPadding
        ));return self
    }
}
// MARK: - 静态 API
public extension JobsToast {
    // ================================== API ==================================
    @discardableResult
    static func show(
        text: String,
        in window: UIWindow? = nil,            // ⚠️ 不用默认取 .wd，避免 actor 警告
        config: Config = .init(),
        tap: ((UIButton) -> Void)? = nil,
        completion: Completion? = nil,
        showDuration: TimeInterval = 0.18,     // ⬅️ 入场动画时长（默认 0.18）
        showDelay: TimeInterval = 0,
        showOptions: UIView.AnimationOptions = [.curveEaseOut]
    ) -> JobsToast {
        // 在主线程里安全获取 window
        let targetWindow = window ?? UIWindow.wd
        // 每窗只保留一个
        removeExistingToast(from: targetWindow)
        // 构建并上屏
        let toast = JobsToast()
            .byCompletion(completion)
            .byTap(tap)
            .byApply(config)
            .byText(text)
            .byAlpha(0)
            .byTransform(CGAffineTransform(scaleX: 0.96, y: 0.96))
            .byAddTo(targetWindow) { make in
                // 你当前是居中展示
                make.center.equalToSuperview()
                make.width.lessThanOrEqualTo(targetWindow.bounds.width - 40)
            }
        // 入场动画（使用参数化时长/延迟/曲线）
        UIView.animate(withDuration: showDuration, delay: showDelay, options: showOptions) {
            toast.byAlpha(1)
            toast.byTransform(.identity)
        }
        // 记录引用：每窗只保留一个
        objc_setAssociatedObject(targetWindow, &currentToastKey, toast, .OBJC_ASSOCIATION_ASSIGN)
        // 定时消失（仍用 config.duration 控制停留时长）
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.15, config.duration)) { [weak toast, weak targetWindow] in
            guard let toast, let targetWindow else { return }
            toast.dismiss(from: targetWindow)
        };return toast
    }
    // 主动消失 —— 无参便捷版（MainActor 内部安全取 wd）
    func dismiss() {
        let targetWindow = UIWindow.wd
        dismiss(from: targetWindow)
    }
    // 主动消失 —— 需要明确传入 window（不提供默认值）
    func dismiss(from window: UIWindow) {
        guard superview != nil else { return }

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn]) {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.97, y: 0.97).translatedBy(x: 0, y: 6)
        } completion: { [weak self, weak window] _ in
            self?.removeFromSuperview()
            if let window { Self.clearAssociatedToast(from: window) }
            self?.completion?()
        }
    }
}
// MARK: - 辅助
private extension JobsToast {
    static func removeExistingToast(from window: UIWindow) {
        if let existing = objc_getAssociatedObject(window, &currentToastKey) as? JobsToast {
            existing.removeFromSuperview()
            clearAssociatedToast(from: window)
        }
    }
    static func clearAssociatedToast(from window: UIWindow) {
        objc_setAssociatedObject(window, &currentToastKey, nil, .OBJC_ASSOCIATION_ASSIGN)
    }
}
