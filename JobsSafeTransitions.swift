//
//  JobsSafeTransitions.swift
//  YourProject
//
//  Created by You on 2025/09/30.
//

import UIKit
import ObjectiveC
// MARK: - Push 防重（UINavigationController）
private struct NavAssoc {
    static var pushingKey: UInt8 = 0
}
private extension UINavigationController {
    var _isPushing: Bool {
        get { (objc_getAssociatedObject(self, &NavAssoc.pushingKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &NavAssoc.pushingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    @inline(__always) func _beginPushGate() { _isPushing = true }
    @inline(__always) func _endPushGate()   { _isPushing = false }
    @inline(__always) func _canPushNow() -> Bool {
        // 系统正在做转场，或我们标记在 push → 都拦掉
        if transitionCoordinator != nil { return false }
        return !_isPushing
    }
}

public enum JobsSafePushSwizzler {
    private static var did = false
    /// 在 App 启动时调用一次
    public static func enable() {
        guard !did else { return }
        did = true
        let cls: AnyClass = UINavigationController.self
        let ori = #selector(UINavigationController.pushViewController(_:animated:))
        let swz = #selector(UINavigationController.jobs_pushViewController_swizzled(_:animated:))
        if let m1 = class_getInstanceMethod(cls, ori),
           let m2 = class_getInstanceMethod(cls, swz) {
            method_exchangeImplementations(m1, m2)
        }
    }
}

public extension UINavigationController {
    /// 被交换后的实现：类型去重 + 动画期闸门
    @objc dynamic func jobs_pushViewController_swizzled(_ vc: UIViewController, animated: Bool) {
        guard _canPushNow() else { return }

        let T = type(of: vc)
        if viewControllers.contains(where: { type(of: $0) == T }) { return }
        if let top = topViewController, type(of: top) == T { return }

        _beginPushGate()
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?._endPushGate() }

        // 调“同名”即系统原始实现（因已交换）
        jobs_pushViewController_swizzled(vc, animated: animated)

        CATransaction.commit()
    }
}
// MARK: - Present 防重（UIViewController）
private struct VCAssoc {
    static var presentingKey: UInt8 = 0
}
private extension UIViewController {
    var _isPresenting: Bool {
        get { (objc_getAssociatedObject(self, &VCAssoc.presentingKey) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &VCAssoc.presentingKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    @inline(__always) func _beginPresentGate() { _isPresenting = true }
    @inline(__always) func _endPresentGate()   { _isPresenting = false }
    @inline(__always) func _canPresentNow() -> Bool {
        if transitionCoordinator != nil { return false }
        if presentedViewController != nil { return false } // 正在展示就别叠加
        return !_isPresenting
    }
}

public enum JobsSafePresentSwizzler {
    private static var did = false
    /// 在 App 启动时调用一次
    public static func enable() {
        guard !did else { return }
        did = true
        let cls: AnyClass = UIViewController.self
        let ori = #selector(UIViewController.present(_:animated:completion:))
        let swz = #selector(UIViewController.jobs_present_swizzled(_:animated:completion:))
        if let m1 = class_getInstanceMethod(cls, ori),
           let m2 = class_getInstanceMethod(cls, swz) {
            method_exchangeImplementations(m1, m2)
        }
    }
}

public extension UIViewController {
    /// 被交换后的实现：动画期闸门 + 同类去重（已展示就是同类则忽略）
    @objc dynamic func jobs_present_swizzled(_ vc: UIViewController,
                                             animated: Bool,
                                             completion: (() -> Void)? = nil) {
        guard _canPresentNow() else { return }

        let T = type(of: vc)
        if let presented = presentedViewController, type(of: presented) == T { return }

        _beginPresentGate()
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?._endPresentGate() }

        // 调系统原生 present（因已交换）
        jobs_present_swizzled(vc, animated: animated, completion: completion)

        CATransaction.commit()
    }
}
