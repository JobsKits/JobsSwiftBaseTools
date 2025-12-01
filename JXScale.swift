//
//  JXScale.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 9/22/25.
//

import UIKit

@inline(__always)
public func ScreenWidth(_ rate:CGFloat = 1) -> CGFloat {
    Screen.width * rate
}

@inline(__always)
public func ScreenHeight(_ rate:CGFloat = 1) -> CGFloat {
    Screen.height * rate
}
// MARK: - 核心比例器
public enum JXScale {
    private static var designW: CGFloat = 390
    private static var designH: CGFloat = 843
    private static var useSafeArea: Bool = false
    
    public static func setup(designWidth: CGFloat,
                             designHeight: CGFloat,
                             useSafeArea: Bool = false) {
        self.designW = designWidth
        self.designH = designHeight
        self.useSafeArea = useSafeArea
    }
    
    public static var screenSize: CGSize {
        guard let window = UIApplication.jobsKeyWindow() else {
            return UIScreen.main.bounds.size
        }
        if useSafeArea {
            let insets = window.safeAreaInsets
            return CGSize(
                width: max(0, window.bounds.width - (insets.left + insets.right)),
                height: max(0, window.bounds.height - (insets.top + insets.bottom))
            )
        } else {
            return window.bounds.size
        }
    }
    
    public static var x: CGFloat { screenSize.width / designW }
    public static var y: CGFloat { screenSize.height / designH }
}

public extension BinaryInteger {
    var w: CGFloat { CGFloat(self) * JXScale.x }
    var h: CGFloat { CGFloat(self) * JXScale.y }
    var fz: CGFloat { CGFloat(self) * JXScale.x }   // 字体缩放，默认跟随 X
}

public extension BinaryFloatingPoint {
    var w: CGFloat { CGFloat(self) * JXScale.x }
    var h: CGFloat { CGFloat(self) * JXScale.y }
    var fz: CGFloat { CGFloat(self) * JXScale.x }
}
// MARK: - 屏幕宽高（兼容设备横竖屏）
public enum Screen {
    /// 当前界面方向（iOS 13+；拿不到时为 .unknown）
    private static var orientation: UIInterfaceOrientation {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?
            .interfaceOrientation ?? .unknown
    }
    /// 屏幕尺寸（以点为单位，已按当前横竖屏纠正宽高）
    public static var size: CGSize {
        let s = UIScreen.main.bounds.size   // iOS 8+ 始终是竖屏坐标
        let w = s.width, h = s.height
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            return CGSize(width: max(w, h), height: min(w, h))
        case .portrait, .portraitUpsideDown:
            return CGSize(width: min(w, h), height: max(w, h))
        default:
            // 拿不到方向时，兜底返回系统给的
            return s
        }
    }
    /// 便捷：当前屏幕宽 / 高（按横竖屏纠正）
    public static var width: CGFloat  { size.width }
    public static var height: CGFloat { size.height }
}
