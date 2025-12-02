Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBaseTools'          # Pod 名
  s.version      = '0.1.11'
  s.summary      = 'Swift@基础工具集'
  s.description  = <<-DESC
                      关于Swift语言下的基础工具集
                   DESC

  s.homepage     = 'https://github.com/JobsKits/JobsSwiftBaseTools'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'Jobs' => 'lg295060456@gmail.com' }

  s.platform      = :ios, '15.0'
  s.swift_version = '5.0'

  s.source = {
    :git => 'https://github.com/JobsKits/JobsSwiftBaseTools.git',
    :tag => s.version.to_s
  }

  # 全局排除脚本 / 图标
  s.exclude_files = [
    'MacOS/🫘JobsPublishPods.command',
    'icon.png',
  ]

  # ====================== 根层基础工具（根目录 Swift） ======================
  s.source_files = [
    'Inlines.swift',
    'JobsRichText.swift',
    'JobsSafeTransitions.swift',
    'JobsText.swift',
    'JobsStructTools.swift',
    'JobsTimer.swift',
    'KeyboardObserver.swift',
    'SafeCodable.swift',
    'SnowflakeSwift.swift',
    'TextInputStrategies.swift',
    'weak.swift'
  ]

  # ====================== 系统库依赖：所有代码共享 ======================
  s.ios.frameworks = 'UIKit',
                     'QuartzCore',
                     'Network',
                     'CoreTelephony',
                     'Photos',
                     'PhotosUI',
                     'AVFoundation',
                     'CoreLocation',
                     'CoreBluetooth',
                     'UniformTypeIdentifiers'

  # ====================== 第三方依赖：所有代码共享 ======================
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'NSObject+Rx'
  s.dependency 'SnapKit'
  s.dependency 'Alamofire'
  s.dependency 'JobsSwiftBaseDefines'

  # ====================== 多语言化（中文目录 + Localizable.strings） ======================
  s.subspec '多语言化' do |ss|
    # 多语言化文件夹下的 Swift：LanguageManager / TRAutoRefresh / TRLang 等
    ss.source_files = '多语言化/**/*.swift'

    # 多语言化下的所有 Localizable.strings
    # 例如：
    #   多语言化/en.lproj/Localizable.strings
    #   多语言化/zh-Hans.lproj/Localizable.strings
    ss.resources = '多语言化/**/*.strings'
  end

  # ====================== 🛜网络流量监控（中文目录） ======================
  s.subspec '🛜网络流量监控' do |ss|
    # 目录：🛜网络流量监控/JobsNetWorkTools.swift
    ss.source_files = '🛜网络流量监控/**/*.swift'
  end
end
