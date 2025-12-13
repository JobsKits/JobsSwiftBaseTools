//
//  JobsTimer.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Mac on 10/4/25.
//

import Foundation
import QuartzCore // CADisplayLink

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif
/**
 JobsTimer
 统一的 Swift 定时器封装：NSTimer / DispatchSourceTimer / CADisplayLink / CFRunLoopTimer（CoreFoundation）

 - 统一协议：start / pause / resume / stop / fireOnce + onTick / onFinish（链式注册）
 - 统一配置：interval、repeats、tolerance、queue、runLoop、runLoopMode
 - 线程安全：回调支持跨线程注册；触发前快照回调，避免遍历时修改导致崩溃
 - 可选（iOS）：自动监听前后台；进入后台自动 pause，回到前台自动 resume
 - 工厂：JobsTimerFactory.make(kind:config:handler:)
 */
// MARK: - 线程安全工具
fileprivate extension NSLock {
    @inline(__always) func jobs_withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
/// 回调容器（线程安全）
/// - 说明：onTick/onFinish 允许跨线程注册；触发时对回调做快照，避免遍历过程中被修改导致 crash
fileprivate final class JobsTimerCallbackBag {
    private let lock = NSLock()
    private var tickBlocks: [jobsByVoidBlock] = []
    private var finishBlocks: [jobsByVoidBlock] = []

    init(initialTick: jobsByVoidBlock? = nil) {
        if let b = initialTick { tickBlocks.append(b) }
    }

    @discardableResult
    func addTick(_ block: @escaping jobsByVoidBlock) -> Self {
        lock.jobs_withLock { tickBlocks.append(block) }
        return self
    }

    @discardableResult
    func addFinish(_ block: @escaping jobsByVoidBlock) -> Self {
        lock.jobs_withLock { finishBlocks.append(block) }
        return self
    }

    func snapshotTickBlocks() -> [jobsByVoidBlock] {
        lock.jobs_withLock { tickBlocks }
    }

    func snapshotFinishBlocks() -> [jobsByVoidBlock] {
        lock.jobs_withLock { finishBlocks }
    }
}
/// App 前后台状态监听（可选）
/// - 目标：JobsTimer 内核不再依赖外部 manager，也能自动 pause/resume
fileprivate final class JobsTimerAppStateMonitor {
    private let enabled: Bool
    private let pauseInBackground: Bool

    private let pause: () -> Void
    private let resume: () -> Void
    private let isRunning: () -> Bool

    private var autoPaused = false

    #if canImport(UIKit)
    private var tokens: [NSObjectProtocol] = []
    #endif

    init(config: JobsTimerConfig,
         pause: @escaping () -> Void,
         resume: @escaping () -> Void,
         isRunning: @escaping () -> Bool) {

        self.enabled = config.autoManageAppState
        self.pauseInBackground = config.pauseInBackground
        self.pause = pause
        self.resume = resume
        self.isRunning = isRunning

        #if canImport(UIKit)
        if enabled && pauseInBackground {
            let nc = NotificationCenter.default

            let t1 = nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onDidEnterBackground()
            }
            let t2 = nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] _ in
                self?.onWillEnterForeground()
            }
            tokens = [t1, t2]
        }
        #endif
    }

    deinit {
        #if canImport(UIKit)
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
        #endif
    }

    /// 在 start() 后调用：如果当前已经在后台，立刻执行一次同步
    func syncWithCurrentAppStateIfNeeded() {
        #if canImport(UIKit)
        guard enabled && pauseInBackground else { return }
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.syncWithCurrentAppStateIfNeeded()
            };return
        }
        let state = UIApplication.shared.applicationState
        if state == .background || state == .inactive {
            onDidEnterBackground()
        }
        #endif
    }

    private func onDidEnterBackground() {
        guard enabled && pauseInBackground else { return }
        guard isRunning() else { return } // 手动暂停的不动
        autoPaused = true
        pause()
    }

    private func onWillEnterForeground() {
        guard enabled && pauseInBackground else { return }
        guard autoPaused else { return }  // 只恢复“被自动暂停”的
        autoPaused = false
        resume()
    }
}
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
    /// ⏱️（仅 Foundation.Timer / CADisplayLink 使用）绑定到哪个 RunLoop
    public var runLoop: RunLoop
    /// ⏱️（仅 Foundation.Timer / CADisplayLink 使用）RunLoop Mode（默认 .common）
    public var runLoopMode: RunLoop.Mode
    /// 🌗 是否在进入后台时自动暂停（默认 true）
    /// - 说明：仅在 canImport(UIKit) 的平台生效；非 iOS 平台会被忽略
    public var pauseInBackground: Bool
    /// 👁 是否自动监听前后台通知（默认 true）
    public var autoManageAppState: Bool

    public init(interval: TimeInterval = 1.0,
                repeats: Bool = true,
                tolerance: TimeInterval = 0.01,
                queue: DispatchQueue = .main,
                runLoop: RunLoop = .main,
                runLoopMode: RunLoop.Mode = .common,
                pauseInBackground: Bool = true,
                autoManageAppState: Bool = true) {
        self.interval = interval
        self.repeats = repeats
        self.tolerance = tolerance
        self.queue = queue
        self.runLoop = runLoop
        self.runLoopMode = runLoopMode
        self.pauseInBackground = pauseInBackground
        self.autoManageAppState = autoManageAppState
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
    func onTick(_ block: @escaping jobsByVoidBlock) -> Self
    /// 注册完成回调（用于一次性定时器或倒计时）
    @discardableResult
    func onFinish(_ block: @escaping jobsByVoidBlock) -> Self
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
// MARK: - NSTimer 实现（升级：只 add 一次 RunLoop；回调线程安全；可选前后台感知）
final class JobsFoundationTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private let stateLock = NSLock()
    private var _isRunning = false
    private var timer: Timer?
    private let callbacks: JobsTimerCallbackBag
    private lazy var appState: JobsTimerAppStateMonitor = {
        JobsTimerAppStateMonitor(
            config: config,
            pause: { [weak self] in self?.pause() },
            resume: { [weak self] in self?.resume() },
            isRunning: { [weak self] in self?.isRunning ?? false }
        )
    }()

    var isRunning: Bool { stateLock.jobs_withLock { _isRunning } }

    init(config: JobsTimerConfig, handler: @escaping jobsByVoidBlock) {
        self.config = config
        self.callbacks = JobsTimerCallbackBag(initialTick: handler)
    }

    func start() {
        stop()
        stateLock.jobs_withLock { _isRunning = true }

        let iv = max(0.0001, config.interval)

        // ✅ 改成 Timer(timeInterval:)：不自动加入 RunLoop，避免 “scheduledTimer + 再 add” 的语义重复
        let t = Timer(timeInterval: iv, repeats: config.repeats) { [weak self] _ in
            guard let self else { return }
            let ticks = self.callbacks.snapshotTickBlocks()
            let finishes = self.callbacks.snapshotFinishBlocks()
            self.config.queue.async {
                ticks.forEach { $0() }
                if !self.config.repeats {
                    finishes.forEach { $0() }
                    self.stop()
                }
            }
        }
        t.tolerance = max(0, config.tolerance)

        // ⚠️ 这里采用 config.runLoop + config.runLoopMode；默认就是 main/common
        config.runLoop.add(t, forMode: config.runLoopMode)

        stateLock.jobs_withLock { timer = t }

        // 若 start 时已在后台，立刻同步一次
        appState.syncWithCurrentAppStateIfNeeded()
    }

    func pause() {
        stateLock.jobs_withLock {
            guard let t = timer else { return }
            t.fireDate = .distantFuture
            _isRunning = false
        }
    }

    func resume() {
        let iv = max(0.0001, config.interval)
        stateLock.jobs_withLock {
            guard let t = timer else { return }
            t.fireDate = Date().addingTimeInterval(iv)
            _isRunning = true
        }
    }

    func fireOnce() {
        let ticks = callbacks.snapshotTickBlocks()
        let finishes = callbacks.snapshotFinishBlocks()
        config.queue.async {
            ticks.forEach { $0() }
            finishes.forEach { $0() }
        }
        stop()
    }

    func stop() {
        let t: Timer? = stateLock.jobs_withLock {
            _isRunning = false
            let old = timer
            timer = nil
            return old
        }
        t?.invalidate()
    }

    @discardableResult
    func onTick(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addTick(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addFinish(block); return self }
}
// MARK: - GCD 实现（升级：回调线程安全；可选前后台感知）
final class JobsGCDTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig

    private let stateLock = NSLock()
    private var _isRunning = false
    private var source: DispatchSourceTimer?
    private var suspended = false

    private let callbacks: JobsTimerCallbackBag
    private lazy var appState: JobsTimerAppStateMonitor = {
        JobsTimerAppStateMonitor(
            config: config,
            pause: { [weak self] in self?.pause() },
            resume: { [weak self] in self?.resume() },
            isRunning: { [weak self] in self?.isRunning ?? false }
        )
    }()

    var isRunning: Bool { stateLock.jobs_withLock { _isRunning } }

    init(config: JobsTimerConfig, handler: @escaping jobsByVoidBlock) {
        self.config = config
        self.callbacks = JobsTimerCallbackBag(initialTick: handler)
    }

    func start() {
        stop()
        stateLock.jobs_withLock { _isRunning = true }

        let s = DispatchSource.makeTimerSource(queue: config.queue)
        let ivNs = UInt64(max(0.0001, config.interval) * 1_000_000_000)
        let leewayNs = UInt64(max(0, config.tolerance) * 1_000_000_000)

        s.schedule(deadline: .now() + .nanoseconds(Int(ivNs)),
                   repeating: .nanoseconds(Int(ivNs)),
                   leeway: .nanoseconds(Int(leewayNs)))

        s.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.isRunning else { return }

            let ticks = self.callbacks.snapshotTickBlocks()
            let finishes = self.callbacks.snapshotFinishBlocks()

            ticks.forEach { $0() }
            if !self.config.repeats {
                finishes.forEach { $0() }
                self.stop()
            }
        }

        stateLock.jobs_withLock {
            source = s
            suspended = false
        }
        s.resume()

        appState.syncWithCurrentAppStateIfNeeded()
    }

    func pause() {
        stateLock.jobs_withLock {
            guard let s = source, !suspended else { return }
            s.suspend()
            suspended = true
            _isRunning = false
        }
    }

    func resume() {
        stateLock.jobs_withLock {
            guard let s = source, suspended else { return }
            s.resume()
            suspended = false
            _isRunning = true
        }
    }

    func fireOnce() {
        let ticks = callbacks.snapshotTickBlocks()
        let finishes = callbacks.snapshotFinishBlocks()
        config.queue.async {
            ticks.forEach { $0() }
            finishes.forEach { $0() }
        }
        stop()
    }

    func stop() {
        let (s, wasSuspended): (DispatchSourceTimer?, Bool) = stateLock.jobs_withLock {
            _isRunning = false
            let old = source
            let sus = suspended
            source = nil
            suspended = false
            return (old, sus)
        }
        guard let s else { return }
        if wasSuspended { s.resume() } // cancel 前必须 resumed
        s.cancel()
    }

    @discardableResult
    func onTick(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addTick(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addFinish(block); return self }
}
// MARK: - CADisplayLink 实现（升级：回调线程安全；可选前后台感知；RunLoop 可配置）
final class JobsDisplayLinkTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private let stateLock = NSLock()
    private var _isRunning = false
    private var link: CADisplayLink?
    private var lastTs: CFTimeInterval = 0
    private var acc: CFTimeInterval = 0
    private let callbacks: JobsTimerCallbackBag
    private lazy var appState: JobsTimerAppStateMonitor = {
        JobsTimerAppStateMonitor(
            config: config,
            pause: { [weak self] in self?.pause() },
            resume: { [weak self] in self?.resume() },
            isRunning: { [weak self] in self?.isRunning ?? false }
        )
    }()

    var isRunning: Bool { stateLock.jobs_withLock { _isRunning } }

    init(config: JobsTimerConfig, handler: @escaping jobsByVoidBlock) {
        self.config = config
        self.callbacks = JobsTimerCallbackBag(initialTick: handler)
    }

    func start() {
        stop()
        stateLock.jobs_withLock {
            _isRunning = true
            acc = 0
            lastTs = 0
        }

        let l = CADisplayLink(target: self, selector: #selector(tick(_:)))
        if #available(iOS 15.0, *), config.interval > 0 {
            let fps = max(1, min(120, Int(round(1.0 / config.interval))))
            l.preferredFrameRateRange = CAFrameRateRange(minimum: 1, maximum: 120, preferred: Float(fps))
        } else if l.responds(to: #selector(getter: CADisplayLink.preferredFramesPerSecond)), config.interval > 0 {
            l.preferredFramesPerSecond = max(1, min(120, Int(round(1.0 / config.interval))))
        }
        // ✅ 使用 config.runLoop + config.runLoopMode（默认 main/common）
        l.add(to: config.runLoop, forMode: config.runLoopMode)
        stateLock.jobs_withLock { link = l }
        appState.syncWithCurrentAppStateIfNeeded()
    }

    func pause() {
        stateLock.jobs_withLock {
            link?.isPaused = true
            _isRunning = false
        }
    }

    func resume() {
        stateLock.jobs_withLock {
            link?.isPaused = false
            _isRunning = true
            lastTs = 0
            acc = 0
        }
    }

    func fireOnce() {
        let ticks = callbacks.snapshotTickBlocks()
        let finishes = callbacks.snapshotFinishBlocks()
        config.queue.async {
            ticks.forEach { $0() }
            finishes.forEach { $0() }
        }
        stop()
    }

    func stop() {
        let l: CADisplayLink? = stateLock.jobs_withLock {
            _isRunning = false
            let old = link
            link = nil
            lastTs = 0
            acc = 0
            return old
        }
        l?.invalidate()
    }

    @discardableResult
    func onTick(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addTick(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addFinish(block); return self }

    @objc private func tick(_ l: CADisplayLink) {
        guard isRunning else { return }

        // 这里在 displaylink 回调线程（通常 main runloop）里计算节拍
        if stateLock.jobs_withLock({ lastTs == 0 }) {
            stateLock.jobs_withLock { lastTs = l.timestamp }
            return
        }

        let dt = l.timestamp - stateLock.jobs_withLock({ lastTs })
        stateLock.jobs_withLock { lastTs = l.timestamp; acc += dt }

        let iv = max(0.0001, config.interval)
        let shouldFire = stateLock.jobs_withLock { acc + max(0, config.tolerance) >= iv }
        guard shouldFire else { return }

        let ticks = callbacks.snapshotTickBlocks()
        let finishes = callbacks.snapshotFinishBlocks()

        stateLock.jobs_withLock {
            acc = config.repeats ? (acc - iv) : 0
        }

        config.queue.async { [weak self] in
            ticks.forEach { $0() }
            if let self, !self.config.repeats {
                finishes.forEach { $0() }
                self.stop()
            }
        }
    }
}
// MARK: - CFRunLoopTimer 实现（升级：回调线程安全；可选前后台感知）
final class JobsRunLoopTimer: JobsTimerProtocol {
    private let config: JobsTimerConfig
    private let stateLock = NSLock()
    private var _isRunning = false
    private var rlTimer: CFRunLoopTimer?
    private let callbacks: JobsTimerCallbackBag
    private lazy var appState: JobsTimerAppStateMonitor = {
        JobsTimerAppStateMonitor(
            config: config,
            pause: { [weak self] in self?.pause() },
            resume: { [weak self] in self?.resume() },
            isRunning: { [weak self] in self?.isRunning ?? false }
        )
    }()

    var isRunning: Bool { stateLock.jobs_withLock { _isRunning } }

    init(config: JobsTimerConfig, handler: @escaping jobsByVoidBlock) {
        self.config = config
        self.callbacks = JobsTimerCallbackBag(initialTick: handler)
    }

    func start() {
        stop()
        stateLock.jobs_withLock { _isRunning = true }

        let iv = max(0.0001, config.interval)

        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + iv,
            config.repeats ? iv : 0,
            0, 0
        ) { [weak self] _ in
            guard let self else { return }

            let ticks = self.callbacks.snapshotTickBlocks()
            let finishes = self.callbacks.snapshotFinishBlocks()

            self.config.queue.async { [weak self] in
                ticks.forEach { $0() }
                guard let self else { return }
                if !self.config.repeats {
                    finishes.forEach { $0() }
                    self.stop()
                }
            }
        }

        CFRunLoopTimerSetTolerance(timer, max(0, config.tolerance))
        // 仍然默认挂在 Main + commonModes（CFRunLoop 不方便直接桥接到 RunLoop 实例）
        let cfRunLoop = config.runLoop.getCFRunLoop()
        let cfMode: CFRunLoopMode = (config.runLoopMode == .common)
        ? .commonModes
        : CFRunLoopMode(config.runLoopMode.rawValue as CFString)
        CFRunLoopAddTimer(cfRunLoop, timer, cfMode)
        stateLock.jobs_withLock { rlTimer = timer }
        appState.syncWithCurrentAppStateIfNeeded()
    }

    func pause() {
        stateLock.jobs_withLock {
            guard let t = rlTimer else { return }
            _isRunning = false
            CFRunLoopTimerSetNextFireDate(t, .infinity)
        }
    }

    func resume() {
        let iv = max(0.0001, config.interval)
        stateLock.jobs_withLock {
            guard let t = rlTimer else { return }
            _isRunning = true
            CFRunLoopTimerSetNextFireDate(t, CFAbsoluteTimeGetCurrent() + iv)
        }
    }

    func fireOnce() {
        let ticks = callbacks.snapshotTickBlocks()
        let finishes = callbacks.snapshotFinishBlocks()
        config.queue.async {
            ticks.forEach { $0() }
            finishes.forEach { $0() }
        }
        stop()
    }

    func stop() {
        let t: CFRunLoopTimer? = stateLock.jobs_withLock {
            _isRunning = false
            let old = rlTimer
            rlTimer = nil
            return old
        }
        if let t { CFRunLoopTimerInvalidate(t) }
    }

    @discardableResult
    func onTick(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addTick(block); return self }

    @discardableResult
    func onFinish(_ block: @escaping jobsByVoidBlock) -> Self { callbacks.addFinish(block); return self }
}
// MARK: - 工厂
public enum JobsTimerFactory {
    public static func make(kind: JobsTimerKind,
                            config: JobsTimerConfig,
                            handler: @escaping jobsByVoidBlock) -> JobsTimerProtocol {
        switch kind {
        case .foundation:   return JobsFoundationTimer(config: config, handler: handler)
        case .gcd:          return JobsGCDTimer(config: config, handler: handler)
        case .displayLink:  return JobsDisplayLinkTimer(config: config, handler: handler)
        case .runLoopCore:  return JobsRunLoopTimer(config: config, handler: handler)
        }
    }
}
