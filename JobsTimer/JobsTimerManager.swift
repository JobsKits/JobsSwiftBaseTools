//
//  JobsTimerManager.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 2025/12/13.
//

import Foundation
#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif
/**
 JobsTimerManager
 基于 Swift Concurrency 的定时器统一管理器（actor）：用 identifier 管理 JobsTimerProtocol，提供“防重复/覆盖”、统一控制、以及前后台策略。

 - Identifier：JobsTimerIdentifiable.timerIdentifier
 - Upsert：同 id 先 stop + remove 再创建；并强制关闭 timer 内核自带前后台监听，统一交由 Manager 处理
 - Controls：start / pause / resume / fireOnceAndRemove / stopAndRemove / stopAndRemoveAll
 - Background：ignore / pauseAndResume（仅恢复自动暂停的）/ cancel（进后台 stop + remove）
 */
// MARK: - Identifier
public protocol JobsTimerIdentifiable: Sendable {
    var timerIdentifier: String { get }
}
// MARK: - Background Policy
public enum JobsTimerBackgroundPolicy: Sendable {
    /// 不处理（后台/前台都不管）
    case ignore
    /// 后台自动 pause，回前台自动 resume（只恢复“自动暂停”的）
    case pauseAndResume
    /// 进后台直接 stop + remove
    case cancel
}
// MARK: - JobsTimerManager (Swift Concurrency / Actor)
public actor JobsTimerManager {
    public static let shared = JobsTimerManager()
    // MARK: - Types
    private enum PauseState {
        case running
        case manualPaused
        case autoPaused
    }

    private struct Entry {
        var timer: any JobsTimerProtocol
        var policy: JobsTimerBackgroundPolicy
        var pauseState: PauseState
    }
    // MARK: - Storage
    private var entries: [String: Entry] = [:]
    // ⚠️ 仅用于持有通知 token；放 nonisolated(unsafe) 是为了解决 Swift 6 下 actor init / deinit 的隔离限制
    nonisolated(unsafe) private var appStateObserver: AppStateObserverBag? = nil
    // MARK: - Init / Deinit
    public init() {
        // iOS Demo：直接用 UIKit 通知，不做 canImport 兼容分支
        let bag = AppStateObserverBag(
            onDidEnterBackground: { [weak self] in
                Task { await self?.handleDidEnterBackground() }
            },
            onWillEnterForeground: { [weak self] in
                Task { await self?.handleWillEnterForeground() }
            }
        )
        self.appStateObserver = bag
    }

    deinit {
        appStateObserver?.invalidate()
        appStateObserver = nil
    }
    // MARK: - Create / Upsert
    /// 创建/覆盖一个 timer（带 identifier、防重复、线程安全、可选前后台策略）
    ///
    /// - Parameters:
    ///   - identifier: 唯一 id
    ///   - kind: JobsTimerKind
    ///   - config: JobsTimerConfig（内部会强制关闭内核自带的 appState 监听，避免“重复监听”）
    ///   - policy: 前后台策略
    ///   - startImmediately: 是否立刻 start()
    ///   - handler: tick 回调（首次 tick）
    @discardableResult
    public func upsertTimer(
        identifier: String,
        kind: JobsTimerKind = .gcd,
        config: JobsTimerConfig = .init(),
        policy: JobsTimerBackgroundPolicy = .pauseAndResume,
        startImmediately: Bool = false,
        handler: @escaping @Sendable () -> Void
    ) -> Bool {

        // 覆盖：先停掉旧的
        if let old = entries[identifier] {
            old.timer.stop()
            entries.removeValue(forKey: identifier)
        }

        var cfg = config
        // ✅ 统一由 Manager 处理前后台，不让内核自己再监听一次（避免重复 pause/resume）
        cfg.autoManageAppState = false
        cfg.pauseInBackground = false

        let timer = JobsTimerFactory.make(kind: kind, config: cfg, handler: handler)
        var entry = Entry(timer: timer, policy: policy, pauseState: .running)

        if startImmediately {
            timer.start()
            entry.pauseState = .running
        } else {
            // 不 start 的情况下，视为非 running（但我们保持状态为 running，等 start 后再正确反映 isRunning）
            entry.pauseState = .running
        }

        entries[identifier] = entry
        return true
    }

    @discardableResult
    public func upsertTimer<ID: JobsTimerIdentifiable>(
        identifier: ID,
        kind: JobsTimerKind = .gcd,
        config: JobsTimerConfig = .init(),
        policy: JobsTimerBackgroundPolicy = .pauseAndResume,
        startImmediately: Bool = false,
        handler: @escaping @Sendable () -> Void
    ) -> Bool {
        upsertTimer(
            identifier: identifier.timerIdentifier,
            kind: kind,
            config: config,
            policy: policy,
            startImmediately: startImmediately,
            handler: handler
        )
    }
    // MARK: - Register Callbacks
    @discardableResult
    public func onTick(identifier: String, _ block: @escaping @Sendable () -> Void) -> Bool {
        guard var entry = entries[identifier] else { return false }
        entry.timer.onTick(block)
        entries[identifier] = entry
        return true
    }

    @discardableResult
    public func onFinish(identifier: String, _ block: @escaping @Sendable () -> Void) -> Bool {
        guard var entry = entries[identifier] else { return false }
        entry.timer.onFinish(block)
        entries[identifier] = entry
        return true
    }
    // MARK: - Controls
    @discardableResult
    public func start(identifier: String) -> Bool {
        guard var entry = entries[identifier] else { return false }
        entry.timer.start()
        entry.pauseState = .running
        entries[identifier] = entry
        return true
    }

    @discardableResult
    public func pause(identifier: String) -> Bool {
        guard var entry = entries[identifier] else { return false }
        entry.timer.pause()
        entry.pauseState = .manualPaused
        entries[identifier] = entry
        return true
    }

    @discardableResult
    public func resume(identifier: String) -> Bool {
        guard var entry = entries[identifier] else { return false }
        entry.timer.resume()
        entry.pauseState = .running
        entries[identifier] = entry
        return true
    }
    /// 执行一次并移除（更符合“一次性触发”的 manager 语义）
    @discardableResult
    public func fireOnceAndRemove(identifier: String) -> Bool {
        guard let entry = entries[identifier] else { return false }
        entry.timer.fireOnce()
        entries.removeValue(forKey: identifier)
        return true
    }

    @discardableResult
    public func stopAndRemove(identifier: String) -> Bool {
        guard let entry = entries[identifier] else { return false }
        entry.timer.stop()
        entries.removeValue(forKey: identifier)
        return true
    }

    public func stopAndRemoveAll() {
        entries.values.forEach { $0.timer.stop() }
        entries.removeAll()
    }
    // MARK: - Query
    public func exists(identifier: String) -> Bool {
        entries[identifier] != nil
    }

    public func isRunning(identifier: String) -> Bool {
        entries[identifier]?.timer.isRunning ?? false
    }

    public func allIdentifiers() -> [String] {
        Array(entries.keys).sorted()
    }
    // MARK: - App State Handling (Actor-isolated)
    private func handleDidEnterBackground() {
        // iOS 通知默认主线程触发，这里在 Task 里 hop 回 actor
        for (id, var entry) in entries {
            switch entry.policy {
            case .ignore:
                continue

            case .cancel:
                entry.timer.stop()
                entries.removeValue(forKey: id)

            case .pauseAndResume:
                // 只对“正在跑且未手动暂停”的自动处理
                guard entry.timer.isRunning else { continue }
                guard entry.pauseState == .running else { continue }

                entry.timer.pause()
                entry.pauseState = .autoPaused
                entries[id] = entry
            }
        }
    }

    private func handleWillEnterForeground() {
        for (id, var entry) in entries {
            guard entry.policy == .pauseAndResume else { continue }
            guard entry.pauseState == .autoPaused else { continue }

            entry.timer.resume()
            entry.pauseState = .running
            entries[id] = entry
        }
    }
}
// MARK: - AppStateObserverBag
fileprivate final class AppStateObserverBag {
    private var tokens: [NSObjectProtocol] = []
    init(
        onDidEnterBackground: @escaping @Sendable () -> Void,
        onWillEnterForeground: @escaping @Sendable () -> Void
    ) {
        let nc = NotificationCenter.default

        let t1 = nc.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            onDidEnterBackground()
        }

        let t2 = nc.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            onWillEnterForeground()
        }

        tokens = [t1, t2]
    }

    func invalidate() {
        tokens.forEach { NotificationCenter.default.removeObserver($0) }
        tokens.removeAll()
    }

    deinit {
        invalidate()
    }
}
// MARK: - Example ID
public enum DemoTimerId: String, JobsTimerIdentifiable {
    case sysCode
    case mark
    case exit
    case backgroundTask

    public var timerIdentifier: String { "com.jobs.timer.\(rawValue)" }
}
/*

 enum TimerId: String, JobsTimerIdentifiable {
     case sysCode, mark, exit
     var timerIdentifier: String { "com.jobs.timer.\(rawValue)" }
 }

 let cfg = JobsTimerConfig(interval: 1, repeats: true, queue: .main)
 let t = try await JobsTimerManager.shared.makeTimer(
     id: TimerId.sysCode,
     kind: .gcd,
     config: cfg,
     dedup: .replaceExisting,
     backgroundPolicy: .pauseInBackground
 ) {
     print("tick")
 }

 try await JobsTimerManager.shared.start(id: TimerId.sysCode.timerIdentifier)

 */
