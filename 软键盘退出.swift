//
//  软键盘退出.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 11/12/25.
//

import UIKit
// MARK: - NSObject 层：只退键盘，按需退 accessory
public extension NSObject {
    /// 收起键盘；`hideAccessory = true` 时连 `inputAccessoryView` 一并收起
    func jobsDismissKeyboard(hideAccessory: Bool = false) {
        // 1) 定位当前第一响应者
        guard let fr = UIResponder.jobsCurrentFirstResponder() else {
            // 没有第一响应者：仅当要求隐藏 accessory 时，退宿主 VC
            if hideAccessory {
                UIApplication.jobsTopMostVC()?.resignFirstResponder()
            };return
        }
        // 2) 只在“输入控件”时退键盘（不影响 VC 的第一响应者身份，工具条不消失）
        if fr is UITextField || fr is UITextView {
            fr.resignFirstResponder()
        } else if hideAccessory {
            // 不是文本输入，但要求隐藏 accessory：退宿主 VC
            // 优先用上下文（如果 self 是 view/VC）
            if let vc = self as? UIViewController {
                vc.resignFirstResponder()
            } else if let view = self as? UIView, let vc = view.jobsNearestVC() {
                vc.resignFirstResponder()
            } else {
                UIApplication.jobsTopMostVC()?.resignFirstResponder()
            }
        }
        // 默认分支：既不是输入控件，也不要求隐藏 accessory -> 什么都不做（避免误把工具条干掉）
    }
}
