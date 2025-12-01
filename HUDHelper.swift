//
//  HUDHelper.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 2025/6/16.
//

import UIKit

final class HUDHelper {
    static let shared = HUDHelper()
    private var hudWindow: UIWindow?

    private init() {}

    func show(message: String, duration: TimeInterval = 2.0) {
        guard let window = jobsGetMainWindow() else { return }

        let label = UILabel()
            .byText(message)
            .byTextColor(.white)
            .byFont(.systemFont(ofSize: 15))
            .byTextAlignment(.center)
            .byBgColor(UIColor(white: 0, alpha: 0.8))

        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.numberOfLines = 0
        label.alpha = 0

        let padding: CGFloat = 20
        let maxSize = CGSize(width: window.frame.width - 2 * padding, height: window.frame.height)
        var size = label.sizeThatFits(maxSize)
        size.width += 2 * padding
        size.height += 2 * padding

        label.frame = CGRect(
            x: (window.frame.width - size.width) / 2,
            y: (window.frame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )

        window.addSubview(label)

        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [], animations: {
                label.alpha = 0
            }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}
