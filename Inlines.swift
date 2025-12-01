//
//  inline.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 2025/6/16.
//

#if os(OSX)
    import AppKit
#endif

#if os(iOS) || os(tvOS)
    import UIKit
#endif
import ObjectiveC
// MARK: - 获取 MainWindow
@inline(__always)
func jobsGetMainWindowBefore13() -> UIWindow? {
    var window: UIWindow?
    // 使用 AppDelegate 的 window 属性
    if let appDelegateWindow = UIApplication.shared.delegate?.window ?? nil {
        window = appDelegateWindow
    }
    // 若仍未获取，尝试使用 keyWindow（仅在 iOS 13 以前）
    if window == nil {
        if #available(iOS 13, *) {
            // iOS 13+ 不再使用 keyWindow
        } else {
            window = UIApplication.shared.perform(#selector(getter: UIApplication.keyWindow))?.takeUnretainedValue() as? UIWindow
        }
    };return window
}

@inline(__always)
func jobsGetMainWindowAfter13() -> UIWindow? {
    if #available(iOS 13.0, *) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            if windowScene.activationState == .foregroundActive {
                for window in windowScene.windows where window.isKeyWindow {
                    return window
                }
                // fallback to first window
                if let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            }
        }
    };return nil
}

@inline(__always)
func jobsGetMainWindow() -> UIWindow? {
    let mainWindowBefore13 = jobsGetMainWindowBefore13()
    let mainWindowAfter13 = jobsGetMainWindowAfter13()
    
    let systemVersion = (UIDevice.current.systemVersion as NSString).floatValue
    let resultWindow = systemVersion >= 13.0 ? mainWindowAfter13 : mainWindowBefore13

    if let window = resultWindow {
        return window
    } else if let window = mainWindowBefore13 {
        return window
    } else if let window = mainWindowAfter13 {
        return window
    } else {
        return nil
    }
}
// MARK: - 手势封装
// self.view.jobs_addGesture(jobsMakeTapGesture { $0.numberOfTapsRequired = 2 })
@inline(__always)
func jobsMakeTapGesture(_ block: ((UITapGestureRecognizer) -> Void)? = nil) -> UITapGestureRecognizer {
    let gesture = UITapGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakeLongPressGesture(_ block: ((UILongPressGestureRecognizer) -> Void)? = nil) -> UILongPressGestureRecognizer {
    let gesture = UILongPressGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakeSwipeGesture(_ block: ((UISwipeGestureRecognizer) -> Void)? = nil) -> UISwipeGestureRecognizer {
    let gesture = UISwipeGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakePanGesture(_ block: ((UIPanGestureRecognizer) -> Void)? = nil) -> UIPanGestureRecognizer {
    let gesture = UIPanGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakePinchGesture(_ block: ((UIPinchGestureRecognizer) -> Void)? = nil) -> UIPinchGestureRecognizer {
    let gesture = UIPinchGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakeRotationGesture(_ block: ((UIRotationGestureRecognizer) -> Void)? = nil) -> UIRotationGestureRecognizer {
    let gesture = UIRotationGestureRecognizer()
    block?(gesture)
    return gesture
}

@inline(__always)
func jobsMakeScreenEdgePanGesture(_ block: ((UIScreenEdgePanGestureRecognizer) -> Void)? = nil) -> UIScreenEdgePanGestureRecognizer {
    let gesture = UIScreenEdgePanGestureRecognizer()
    block?(gesture)
    return gesture
}
