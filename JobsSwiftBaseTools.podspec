Pod::Spec.new do |s|
  s.name         = 'JobsSwiftBaseTools'          # Pod 名
  s.version      = '0.1.5'
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
  s.exclude_files = 'MacOS/🫘JobsPublishPods.command'

  # Pod 级别依赖：所有 subspec 共用
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

  s.dependency 'RxSwift'
  s.dependency 'RxCocoa'
  s.dependency 'NSObject+Rx'
  s.dependency 'SnapKit'
  s.dependency 'Alamofire'
  s.dependency 'JobsSwiftBaseDefines'

  # 默认安装哪些 subspec（pod 'JobsSwiftBaseTools' 时）
  s.default_subspecs = ['Core', 'Localization', 'NetworkMonitor']

  # ====================== Core（根目录工具） ======================
  s.subspec 'Core' do |ss|
    # 根目录所有 Swift（不会包含子目录）
    ss.source_files = [
      '*.swift'
    ]

    # icon 也一起打进来（如果你想）
    ss.resource_bundles = {
      'JobsSwiftBaseTools' => [
        'icon.png'
      ]
    }
  end

  # ====================== Localization（多语言化） ======================
  s.subspec 'Localization' do |ss|
    # 一般会依赖 Core 提供的一些工具类型
    ss.dependency 'JobsSwiftBaseTools/Core'

    ss.source_files = '多语言化/**/*.swift'

    # 多语言资源：zh-Hans.lproj + 其他你后面加的 lproj 都可以一起放
    ss.resource_bundles = {
      # 注意：bundle 名不能和别的地方重复
      'JobsSwiftBaseTools.Localization' => [
        '多语言化/zh-Hans.lproj/**/*'
      ]
    }
  end

  # ====================== NetworkMonitor（网络流量监控） ======================
  s.subspec 'NetworkMonitor' do |ss|
    ss.dependency 'JobsSwiftBaseTools/Core'

    ss.source_files = '网络流量监控/**/*.swift'
  end
end
