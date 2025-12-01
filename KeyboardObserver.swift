//
//  KeyboardObserver.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 9/30/25.
//

import UIKit
import ObjectiveC
import RxSwift
import RxCocoa
import NSObject_Rx

final class KeyboardObserver {
    static let shared = KeyboardObserver()

    private var onChange: ((CGFloat, Bool) -> Void)?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    func listen(_ callback: @escaping (_ height: CGFloat, _ isVisible: Bool) -> Void) {
        onChange = callback
    }

    @objc private func onShow(_ note: Notification) {
        let height = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
        onChange?(height, true)
    }

    @objc private func onHide(_ note: Notification) {
        onChange?(0, false)
    }
}
/**

 KeyboardObserver.shared.listen { height, isVisible in
     if isVisible {
         print("📱 键盘弹出，高度: \(height)")
     } else {
         print("📱 键盘收起")
     }
 }

 final class DemoVC: UIViewController {
     private let bag = DisposeBag()

     override func viewDidAppear(_ animated: Bool) {
         super.viewDidAppear(animated)

         // 关键：此时 view 已经在 window 上，才能正确计算坐标与安全区
         view.keyboardHeight
             .subscribe(onNext: { height in
                 print("🧠 当前键盘高度: \(height)")
                 // 根据 height 更新底部约束/内容 inset/滚动区域等
             })
             .disposed(by: bag)
     }
 }

 */
