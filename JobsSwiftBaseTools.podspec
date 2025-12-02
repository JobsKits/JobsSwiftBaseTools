Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBaseTools'          # Pod 名
  s.version      = '0.1.9'
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

  # 全局排除脚本
  s.exclude_files = ['MacOS/🫘JobsPublishPods.command','icon.png',]

  # ====== 源码：主 Pod 直接包含所有 Swift（根目录 + 多语言 + 网络监控）======
  s.source_files = [
    '*.swift',
    '多语言化/**/*.swift',
    '🛜网络流量监控/**/*.swift'
  ]

  # ====== 资源：icon + 本地化，直接打进目标工程的根 Bundle，不建 .bundle ======
  s.resources = [
    '多语言化/zh-Hans.lproj/**/*'
  ]

  # ====== 系统库依赖：所有代码共享 ======
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

  # ====== 第三方依赖：所有代码共享 ======
  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'NSObject+Rx'
  s.dependency 'SnapKit'
  s.dependency 'Alamofire'
  s.dependency 'JobsSwiftBaseDefines'

  # ====================== 多语言化（多语言化分组） ======================
  s.subspec '多语言化' do |ss|
    ss.source_files = '多语言化/**/*.swift'
  end

  # ====================== 🛜网络流量监控（网络流量监控分组） ======================
  s.subspec '🛜网络流量监控' do |ss|
    ss.source_files = '🛜网络流量监控/**/*.swift'
  end
end
