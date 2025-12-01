//
//  JobsTimer.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/4/25.
//

import Foundation
import QuartzCore // CADisplayLink
// MARK: - 配置体
public struct JobsTimerConfig {
    /// 🔁 每次触发的时间间隔（秒）
    public var interval: TimeInterval
    /// ♻️ 是否重复执行。若为 `false`，触发一次后即自动销毁
    public var repeats: Bool
    /// ⚙️ 允许系统在此范围内微调触发时间，以提升能效与系统同步性
    public var tolerance: TimeInterval
    /// 🧵 执行回调的目标队列（UI 更新一般用 .main）
    public var queue: DispatchQueue

    public init(interval: TimeInterval = 1.0,
                repeats: Bool = true,
                tolerance: TimeInterval = 0.01,
                queue: DispatchQueue = .main) {
        self.interval = interval
        self.repeats = repeats
        self.tolerance = tolerance
        self.queue = queue
    }
}
// MARK: - 统一协议
public protocol JobsTimerProtocol: AnyObject {
    /// 当前是否运行中
    var isRunning: Bool { get }
    /// 启动计时器
    func start()
    /// 暂停计时器
    func pause()
    /// 恢复计时器
    func resume()
    /// 停止计时器（销毁@有回调）
    func fireOnce()
    /// 停止计时器（销毁@无回调）
    func stop()
    /// 注册回调（每 tick 执行一次）
    @discardableResult
    func onTick(_ block: @escaping () -> Void) -> Self
    /// 注册完成回调（用于一次性定时器或倒计时）
    @discardableResult
    func onFinish(_ block: @escaping () -> Void) -> Self
}
// MARK: - 定时器内核枚举
public enum JobsTimerKind: String, CaseIterable {
    case foundation     // Foundation.Timer
    case gcd            // DispatchSourceTimer
    case displayLink    // CADisplayLink
    case runLoopCore    // CFRunLoopTimer:NSTimer 背后的 C 语言/CoreFoundation层 原始定时器
}
// 显示名
public extension JobsTimerKind {
    var jobs_displayName: String {
        switch self {
        case .foundation:   return "NSTimer"
        case .gcd:          return "GCD"
        case .displayLink:  return "DisplayLink"
        case .runLoopCore:  return "RunLoop"
        }
    }
}
// MARK: - NSTimer 实现
final class JobsFoundationTimer: JobsTimerProtocol {
    private var timer: Timer?
    private let config: JobsTimerConfig
    private var tickBlocks: [() -> Void] = []
    private var finishBlocks: [() -> Void] = []
    private(set) var isRunning = false

    init(config: JobsTimerConfig, handler: @escaping () -> Void) {
        self.config = config
        self.tickBlocks.append(handler)
    }

    func start() {
        stop()
        isRunning = true
        let t = Timer.scheduledTimer(withTimeInterval: max(0.0001, config.interval),
                                     repeats: config.repeats) { [weak self] _ in
            guard let self else { return }
            self.config.queue.async {
                self.tickBlocks.forEach { $0() }
                if !self.config.repeats {
                    self.finishBlocks.forEach { $0() }
                    self.stop()
                }
            }
        }
        t.tolerance = max(0, config.tolerance)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        guard let t = timer else { return }
        t.fireDate = .distantFuture
        isRunning = false
    }

    func resume() {
        guard let t = timer else { return }
        t.fireDate = Date().addingTimeInterval(max(0.0001, config.interval))
        isRunning = true
    }

    func fireOnce() {
        config.queue.async { [weak self] in
            guard let self else { return }
            self.tickBlocks.forEach { $0() }
            self.finishBlocks.forEach { $0() }
        }
        stop()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    @discardableResult
    func onTick(_ block: @escaping () -> Void) -> Self { tickBlocks.append(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping () -> Void) -> Self { finishBlocks.append(block); return self }
}

// MARK: - GCD 实现
final class JobsGCDTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private var source: DispatchSourceTimer?
    private var suspended = false
    private(set) var isRunning = false

    private var tickBlocks: [() -> Void] = []
    private var finishBlocks: [() -> Void] = []

    init(config: JobsTimerConfig, handler: @escaping () -> Void) {
        self.config = config
        self.tickBlocks.append(handler)
    }

    func start() {
        stop()
        isRunning = true
        let s = DispatchSource.makeTimerSource(queue: config.queue)
        let ivNs = UInt64(max(0.0001, config.interval) * 1_000_000_000)
        s.schedule(deadline: .now() + .nanoseconds(Int(ivNs)),
                   repeating: .nanoseconds(Int(ivNs)),
                   leeway: .nanoseconds(Int(max(0, config.tolerance) * 1_000_000_000)))
        s.setEventHandler { [weak self] in
            guard let self, self.isRunning else { return }
            self.tickBlocks.forEach { $0() }
            if !self.config.repeats {
                self.finishBlocks.forEach { $0() }
                self.stop()
            }
        }
        s.resume()
        source = s
        suspended = false
    }

    func pause() {
        guard let s = source, !suspended else { return }
        s.suspend()
        suspended = true
        isRunning = false
    }

    func resume() {
        guard let s = source, suspended else { return }
        s.resume()
        suspended = false
        isRunning = true
    }

    func fireOnce() {
        config.queue.async { [tickBlocks, finishBlocks] in
            tickBlocks.forEach { $0() }
            finishBlocks.forEach { $0() }
        }
        stop()
    }

    func stop() {
        isRunning = false
        guard let s = source else { return }
        if suspended { s.resume() } // cancel 前必须 resumed
        s.cancel()
        source = nil
        suspended = false
    }

    @discardableResult
    func onTick(_ block: @escaping () -> Void) -> Self { tickBlocks.append(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping () -> Void) -> Self { finishBlocks.append(block); return self }
}

// MARK: - CADisplayLink 实现
final class JobsDisplayLinkTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private var link: CADisplayLink?
    private var lastTs: CFTimeInterval = 0
    private var acc: CFTimeInterval = 0
    private(set) var isRunning = false

    private var tickBlocks: [() -> Void] = []
    private var finishBlocks: [() -> Void] = []

    init(config: JobsTimerConfig, handler: @escaping () -> Void) {
        self.config = config
        self.tickBlocks.append(handler)
    }

    func start() {
        stop()
        isRunning = true
        acc = 0
        lastTs = 0

        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 15.0, *), config.interval > 0 {
            let fps = max(1, min(120, Int(round(1.0 / config.interval))))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 120, preferred: Float(fps))
        } else if l.responds(to: #selector(getter: CADisplayLink.preferredFramesPerSecond)), config.interval > 0 {
            l.preferredFramesPerSecond = max(1, min(120, Int(round(1.0 / config.interval))))
        }
        l.add(to: .main, forMode: .common)
        link = l
    }

    func pause() { link?.isPaused = true;  isRunning = false }
    func resume() { link?.isPaused = false; isRunning = true; lastTs = 0; acc = 0 }

    func fireOnce() {
        config.queue.async { [tickBlocks, finishBlocks] in
            tickBlocks.forEach { $0() }
            finishBlocks.forEach { $0() }
        }
        stop()
    }

    func stop() {
        isRunning = false
        link?.invalidate()
        link = nil
        lastTs = 0
        acc = 0
    }

    @discardableResult
    func onTick(_ block: @escaping () -> Void) -> Self { tickBlocks.append(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping () -> Void) -> Self { finishBlocks.append(block); return self }

    @objc private func tick(_ l: CADisplayLink) {
        guard isRunning else { return }
        if lastTs == 0 { lastTs = l.timestamp; return }
        let dt = l.timestamp - lastTs
        lastTs = l.timestamp
        acc += dt

        let iv = max(0.0001, config.interval)
        if acc + max(0, config.tolerance) >= iv {
            acc = config.repeats ? (acc - iv) : 0
            config.queue.async { [self] in
                self.tickBlocks.forEach { $0() }
                if !self.config.repeats {
                    self.finishBlocks.forEach { $0() }
                    self.stop()
                }
            }
        }
    }
}
// MARK: - CFRunLoopTimer 实现
final class JobsRunLoopTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private var rlTimer: CFRunLoopTimer?
    private(set) var isRunning = false

    private var tickBlocks: [() -> Void] = []
    private var finishBlocks: [() -> Void] = []

    init(config: JobsTimerConfig, handler: @escaping () -> Void) {
        self.config = config
        self.tickBlocks.append(handler)
    }

    func start() {
        stop()
        isRunning = true

        let iv = max(0.0001, config.interval)
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + iv,
            config.repeats ? iv : 0,
            0, 0
        ) { [weak self] _ in
            guard let self else { return }
            self.config.queue.async {
                self.tickBlocks.forEach { $0() }
                if !self.config.repeats {
                    self.finishBlocks.forEach { $0() }
                    self.stop()
                }
            }
        }
        CFRunLoopTimerSetTolerance(timer, max(0, config.tolerance))
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
        rlTimer = timer
    }

    func pause() {
        guard let t = rlTimer else { return }
        isRunning = false
        CFRunLoopTimerSetNextFireDate(t, .infinity)
    }

    func resume() {
        guard let t = rlTimer else { return }
        isRunning = true
        CFRunLoopTimerSetNextFireDate(t, CFAbsoluteTimeGetCurrent() + max(0.0001, config.interval))
    }

    func fireOnce() {
        config.queue.async { [tickBlocks, finishBlocks] in
            tickBlocks.forEach { $0() }
            finishBlocks.forEach { $0() }
        }
        stop()
    }

    func stop() {
        isRunning = false
        if let t = rlTimer {
            CFRunLoopTimerInvalidate(t)
            rlTimer = nil
        }
    }

    @discardableResult
    func onTick(_ block: @escaping () -> Void) -> Self { tickBlocks.append(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping () -> Void) -> Self { finishBlocks.append(block); return self }
}
// MARK: - 工厂
public enum JobsTimerFactory {
    public static func make(kind: JobsTimerKind,
                            config: JobsTimerConfig,
                            handler: @escaping () -> Void) -> JobsTimerProtocol {
        switch kind {
        case .foundation:   return JobsFoundationTimer(config: config, handler: handler)
        case .gcd:          return JobsGCDTimer(config: config, handler: handler)
        case .displayLink:  return JobsDisplayLinkTimer(config: config, handler: handler)
        case .runLoopCore:  return JobsRunLoopTimer(config: config, handler: handler)
        }
    }
}
