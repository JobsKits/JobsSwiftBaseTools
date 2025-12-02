Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBaseTools'          # Pod 名
  s.version      = '0.1.4'
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

  # ====== 源码文件（包含根目录 + “多语言化” + “网络流量监控”） ======
  # 这些路径都是“相对于 podspec 所在目录”
  s.exclude_files = 'MacOS/🫘JobsPublishPods.command'  # 路径按你仓库真实结构写
  s.source_files = [
    '*.swift',                 # 根目录下所有 .swift
    '多语言化/**/*.swift',      # 多语言化 文件夹里的 .swift
    '网络流量监控/**/*.swift'   # 网络流量监控 文件夹里的 .swift
  ]

  # ====== 资源（icon + 本地化 .lproj）======
  # 如果你希望 zh-Hans.lproj 里的 Localizable.strings 也打进 Pod：
  s.resource_bundles = {
    'JobsSwiftBaseTools' => [
      'icon.png',                         # 根目录 icon
      '多语言化/zh-Hans.lproj/**/*'       # 多语言化/zh-Hans.lproj 里的所有资源
    ]
  }

  # ====== 系统库依赖 ======
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

  # ====== 第三方依赖 ======
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'NSObject+Rx'
  s.dependency 'SnapKit'
  s.dependency 'Alamofire'
  s.dependency 'JobsSwiftBaseDefines'
end
