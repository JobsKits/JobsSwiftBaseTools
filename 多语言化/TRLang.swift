//
//  TRLang.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 11/1/25.
//

import Foundation
// MARK: - 统一语言桥（无兼容分支，仅此一套）
public enum TRLang {
    // 原来是: public static var bundleProvider: (() -> Bundle)?
    public static var bundleProvider: () -> Bundle = { .main }
    // 原来是可选；如果你确实需要它，给个安全默认
    public static var localeCodeProvider: () -> String = { Locale.current.identifier }
    @inline(__always)
    public static func bundle() -> Bundle { bundleProvider() }
}
