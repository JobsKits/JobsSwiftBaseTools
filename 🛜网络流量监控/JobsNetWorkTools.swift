//
//  JobsNetWorkTools.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 11/17/25.
//

import Foundation
import Darwin
import Network
import CoreTelephony
/// 🛜网络流量监控
// MARK: - 数据源类型（当前网络来源）
enum JobsNetworkSource {
    case wifi
    case cellular
    case other
    case none

    var displayName: String {
        switch self {
        case .wifi:     return "Wi-Fi"
        case .cellular: return "蜂窝"
        case .other:    return "其他"
        case .none:     return "无网络"
        }
    }
}
// MARK: - 获取当前总上传/下载字节（Wi-Fi + 蜂窝）
/// 单一方向的总字节数：下行 / 上行
struct NetworkBytes {
    let download: UInt64   // 下行总字节数
    let upload: UInt64     // 上行总字节数

    init(download: UInt64 = 0, upload: UInt64 = 0) {
        self.download = download
        self.upload = upload
    }
}
/// 按来源拆分的字节统计
struct NetworkSplitBytes {
    let wifi: NetworkBytes
    let cellular: NetworkBytes
    let other: NetworkBytes

    /// 所有来源合计
    var total: NetworkBytes {
        NetworkBytes(
            download: wifi.download &+ cellular.download &+ other.download,
            upload:   wifi.upload   &+ cellular.upload   &+ other.upload
        )
    }
}
/// 读取当前所有网络接口的总上下行字节（只统计 UP 状态的 Wi-Fi / 蜂窝 / 其他）
func currentNetworkBytesSplit() -> NetworkSplitBytes {
    var addrs: UnsafeMutablePointer<ifaddrs>?
    var wifiIn: UInt64 = 0
    var wifiOut: UInt64 = 0
    var cellIn: UInt64 = 0
    var cellOut: UInt64 = 0
    var otherIn: UInt64 = 0
    var otherOut: UInt64 = 0

    guard getifaddrs(&addrs) == 0, let firstAddr = addrs else {
        return NetworkSplitBytes(
            wifi: NetworkBytes(),
            cellular: NetworkBytes(),
            other: NetworkBytes()
        )
    }

    var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

    while let ifa = ptr?.pointee {
        let flags = Int32(ifa.ifa_flags)
        // 只算 UP 的接口
        guard (flags & IFF_UP) == IFF_UP else {
            ptr = ifa.ifa_next
            continue
        }

        let name = String(cString: ifa.ifa_name)

        if let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self).pointee {
            let inBytes  = UInt64(data.ifi_ibytes)
            let outBytes = UInt64(data.ifi_obytes)

            // en0 / en1... 一般是 Wi-Fi（也可能有有线），pdp_ip0... 一般是蜂窝
            if name.hasPrefix("en") {
                wifiIn  &+= inBytes
                wifiOut &+= outBytes
            } else if name.hasPrefix("pdp_ip") {
                cellIn  &+= inBytes
                cellOut &+= outBytes
            } else {
                otherIn  &+= inBytes
                otherOut &+= outBytes
            }
        }

        ptr = ifa.ifa_next
    }
    freeifaddrs(addrs)

    return NetworkSplitBytes(
        wifi: NetworkBytes(download: wifiIn, upload: wifiOut),
        cellular: NetworkBytes(download: cellIn, upload: cellOut),
        other: NetworkBytes(download: otherIn, upload: otherOut)
    )
}
/// 向后兼容：总字节数（Wi-Fi + 蜂窝 + 其他）
func currentNetworkBytes() -> NetworkBytes {
    currentNetworkBytesSplit().total
}
// MARK: - 网络流量监控（来源 + 上下行速度）
/// 统一的网络流量监控：
/// - 每 interval 秒回调一次当前网络来源 + 上/下行速度（Bytes/s）
/// - 内部用 NWPathMonitor + getifaddrs 统计总字节差值
final class JobsNetworkTrafficMonitor {
    static let shared = JobsNetworkTrafficMonitor()
    /// 回调：当前来源 + 上/下行速度（Bytes/s）
    /// - source: 当前网络来源（Wi-Fi / 蜂窝 / 其他 / 无）
    /// - up: 上行速度（Bytes/s）
    /// - down: 下行速度（Bytes/s）
    var onUpdate: ((JobsNetworkSource, Double, Double) -> Void)?

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "jobs.network.path")
    private var timer: DispatchSourceTimer?

    private var lastBytes: NetworkBytes?
    public var currentSource: JobsNetworkSource = .none

    private init() {
        // 监听当前网络类型
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            let source: JobsNetworkSource
            if path.status != .satisfied {
                source = .none
            } else if path.usesInterfaceType(.wifi) {
                source = .wifi
            } else if path.usesInterfaceType(.cellular) {
                source = .cellular
            } else {
                source = .other
            }

            DispatchQueue.main.async {
                self.currentSource = source
            }
        }
        pathMonitor.start(queue: pathQueue)
    }
    /// 开始定时统计网速，默认 1s 一次
    func start(interval: TimeInterval = 1.0) {
        stop()
        lastBytes = currentNetworkBytes()

        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.global())
        t.schedule(deadline: .now() + interval, repeating: interval)

        t.setEventHandler { [weak self] in
            guard let self else { return }
            guard let last = self.lastBytes else {
                self.lastBytes = currentNetworkBytes()
                return
            }

            let now = currentNetworkBytes()
            let deltaIn  = Double(now.download &- last.download)
            let deltaOut = Double(now.upload   &- last.upload)

            let downSpeed = deltaIn / interval   // Bytes/s
            let upSpeed   = deltaOut / interval  // Bytes/s
            let source    = self.currentSource

            self.lastBytes = now

            DispatchQueue.main.async {
                self.onUpdate?(source, upSpeed, downSpeed)
            }
        }

        t.resume()
        timer = t
    }
    /// 停止流量监控
    func stop() {
        timer?.cancel()
        timer = nil
        lastBytes = nil
    }
}
// MARK: - DSL 风格链式封装
extension JobsNetworkTrafficMonitor {
    @discardableResult
    func byOnUpdate(_ block: @escaping (JobsNetworkSource, Double, Double) -> Void) -> Self {
        self.onUpdate = block
        return self
    }

    @discardableResult
    func byStart(interval: TimeInterval = 1.0) -> Self {
        start(interval: interval)
        return self
    }
    /// 当前系统首选网络来源（基于 NWPathMonitor）
    var jobsCurrentSource: JobsNetworkSource {
        currentSource
    }
}
// MARK: - 单位格式化（B/s -> KB/s / MB/s）
func jobs_formatSpeed(_ bytesPerSec: Double) -> String {
    if bytesPerSec < 1024 {
        return String(format: "%.0f B/s", bytesPerSec)
    } else if bytesPerSec < 1024 * 1024 {
        return String(format: "%.1f KB/s", bytesPerSec / 1024)
    } else {
        return String(format: "%.2f MB/s", bytesPerSec / 1024 / 1024)
    }
}
// MARK: - 蜂窝 / Wi-Fi 运营商信息
/// 当前蜂窝运营商信息（如果有的话）
func currentCellularCarrierDescription() -> String? {
    let networkInfo = CTTelephonyNetworkInfo()
    // iOS 12+ 可能有多卡
    if #available(iOS 12.0, *) {
        guard let providers = networkInfo.serviceSubscriberCellularProviders else { return nil }
        let descs: [String] = providers.values.compactMap { carrier in
            var parts: [String] = []
            if let name = carrier.carrierName {
                parts.append(name)
            }
            if let mcc = carrier.mobileCountryCode, let mnc = carrier.mobileNetworkCode {
                parts.append("MCC/MNC: \(mcc)/\(mnc)")
            }
            if carrier.isoCountryCode != nil {
                // 可以扩展更多字段
            }
            return parts.isEmpty ? nil : parts.joined(separator: "，")
        }
        return descs.isEmpty ? nil : descs.joined(separator: " | ")
    } else {
        guard let carrier = networkInfo.subscriberCellularProvider else { return nil }
        var parts: [String] = []
        if let name = carrier.carrierName {
            parts.append(name)
        }
        if let mcc = carrier.mobileCountryCode, let mnc = carrier.mobileNetworkCode {
            parts.append("MCC/MNC: \(mcc)/\(mnc)")
        }
        return parts.isEmpty ? nil : parts.joined(separator: "，")
    }
}
// MARK: - 当前网络类型描述（Wi-Fi / 蜂窝 / 其他）
/// 使用 NWPathMonitor 获取当前网络类型
func currentNetworkSource() -> JobsNetworkSource {
    // 这里简单挪用 JobsNetworkTrafficMonitor 的 currentSource
    JobsNetworkTrafficMonitor.shared.byStart(interval: 10) // 轻启一个定时器，防止完全没初始化
    return JobsNetworkTrafficMonitor.shared.onUpdate.map { _ in
        // 如果 onUpdate 有人监听，就用监听时更新过的 currentSource
        // 否则临时起一个 NWPathMonitor 也行，这里为简单起见用已有对象
        // 但要注意：第一次拿到值可能有一点延迟。
        JobsNetworkTrafficMonitor.shared.currentSource
    } ?? .none
}
// MARK: - 等待“有真实流量”的监控（基于字节差值）
/// 等待 Wi-Fi / 蜂窝“有真实数据传输”
///
/// 使用场景：
/// - 比如你在「只在 Wi-Fi 下自动播放视频」的业务里，希望确认 _确实已经有真实的下行数据_ 再开始播；
/// - 或者在蜂窝网络下，想要在「真的有数据流量已经开始跑」之后，才算进入计费逻辑（比如上报一次埋点）。
///
/// 实现思路：
/// - 每隔 interval 秒读取一次 `currentNetworkBytesSplit()`；
/// - 只关心「Wi-Fi 字节数的增量」「蜂窝字节数的增量」是否 > 0；
/// - 分别对 Wi-Fi / 蜂窝做一次「首包回调」。
///
/// 注意：
/// - 这个逻辑只判断「网卡层的字节变化」，无法保证一定是你 App 发起的请求；
/// - 但在你触发了自己的网络请求之后再调用本方法，基本可以认为“出现的新增流量”与当前操作有强相关性。
final class JobsNetworkDataReadyMonitor {

    static let shared = JobsNetworkDataReadyMonitor()

    private let queue = DispatchQueue(label: "jobs.network.ready")
    private var timer: DispatchSourceTimer?

    private var lastWiFi: NetworkBytes?
    private var lastCellular: NetworkBytes?

    private var waiting: Bool = false
    private var wifiDone: Bool = false
    private var cellularDone: Bool = false
    private var deadline: CFAbsoluteTime?

    private init() {}

    /// 等到“有数据流动”之后仅回调一次（Wi-Fi / 蜂窝 分别触发）。
    ///
    /// - Parameters:
    ///   - interval: 轮询间隔（秒），建议 0.5 ~ 1.0 之间
    ///   - timeout: 超时时间（可选；为 nil 则一直等）
    ///   - onWiFiReady: 第一次探测到 Wi-Fi 有数据流动时触发（主线程回调，可选）
    ///   - onCellularReady: 第一次探测到蜂窝有数据流动时触发（主线程回调，可选）
    ///   - onTimeout: 超时仍无任何数据时触发（主线程回调，可选）
    func waitOnce(
        interval: TimeInterval = 0.5,
        timeout: TimeInterval? = 10,
        onWiFiReady: (() -> Void)? = nil,
        onCellularReady: (() -> Void)? = nil,
        onTimeout: (() -> Void)? = nil
    ) {
        queue.async { [weak self] in
            guard let self else { return }

            // 清理旧的
            self.stopLocked()

            // 如果两个回调都没传，其实就没必要等
            self.wifiDone = (onWiFiReady == nil)
            self.cellularDone = (onCellularReady == nil)
            self.waiting = !(self.wifiDone && self.cellularDone)
            guard self.waiting else { return }

            // 记录起始字节
            let split = currentNetworkBytesSplit()
            self.lastWiFi = split.wifi
            self.lastCellular = split.cellular

            if let timeout = timeout {
                self.deadline = CFAbsoluteTimeGetCurrent() + timeout
            } else {
                self.deadline = nil
            }

            let t = DispatchSource.makeTimerSource(queue: self.queue)
            t.schedule(deadline: .now() + interval, repeating: interval)

            t.setEventHandler { [weak self] in
                guard let self else { return }
                guard self.waiting else { return }

                // 使用 NWPathMonitor 的主线路信息做“互斥判断”：
                // - 如果同时传了 Wi-Fi / 蜂窝两个回调，就只触发当前主线路对应的那个；
                // - 如果只传了其中一个，则保持原本“只要有对应流量就触发”的行为。
                let primary = JobsNetworkTrafficMonitor.shared.jobsCurrentSource
                let exclusive = (onWiFiReady != nil && onCellularReady != nil)

                let nowSplit = currentNetworkBytesSplit()
                let nowWiFi = nowSplit.wifi
                let nowCell = nowSplit.cellular

                // Wi-Fi 首包
                if !self.wifiDone, let last = self.lastWiFi {
                    let deltaDown = nowWiFi.download &- last.download
                    let deltaUp   = nowWiFi.upload   &- last.upload
                    if deltaDown > 0 || deltaUp > 0 {
                        // exclusive 模式下，如果系统当前主线路是蜂窝，则忽略 Wi-Fi 抖动
                        if !exclusive || primary != .cellular {
                            self.wifiDone = true
                            if let onWiFiReady = onWiFiReady {
                                DispatchQueue.main.async { onWiFiReady() }
                            }
                        }
                    }
                }

                // 蜂窝首包
                if !self.cellularDone, let last = self.lastCellular {
                    let deltaDown = nowCell.download &- last.download
                    let deltaUp   = nowCell.upload   &- last.upload
                    if deltaDown > 0 || deltaUp > 0 {
                        // exclusive 模式下，如果系统当前主线路是 Wi-Fi，则忽略蜂窝抖动
                        if !exclusive || primary != .wifi {
                            self.cellularDone = true
                            if let onCellularReady = onCellularReady {
                                DispatchQueue.main.async { onCellularReady() }
                            }
                        }
                    }
                }

                self.lastWiFi = nowWiFi
                self.lastCellular = nowCell

                // 两边都已经触发完了，收工
                if self.wifiDone && self.cellularDone {
                    self.stopLocked()
                    return
                }

                // 超时兜底（只在完全没有任何流量时才触发）
                if let deadline = self.deadline,
                   CFAbsoluteTimeGetCurrent() >= deadline {
                    let firedAny = self.wifiDone || self.cellularDone
                    self.stopLocked()
                    if !firedAny, let onTimeout = onTimeout {
                        DispatchQueue.main.async { onTimeout() }
                    }
                }
            }

            self.timer = t
            t.resume()
        }
    }
    /// 主动取消等待（比如 VC 要销毁了）
    func cancel() {
        queue.async { [weak self] in
            self?.stopLocked()
        }
    }
    // MARK: - 内部清理（在 queue 上调用）
    private func stopLocked() {
        timer?.cancel()
        timer = nil

        lastWiFi = nil
        lastCellular = nil

        waiting = false
        wifiDone = false
        cellularDone = false
        deadline = nil
    }
}
/// 取消当前这一次网络数据就绪的等待
func JobsCancelWaitNetworkDataReady() {
    JobsNetworkDataReadyMonitor.shared.cancel()
}
/// 停止网络实时监听
func JobsNetworkTrafficMonitorStop() {
    JobsNetworkTrafficMonitor.shared.stop()
}
// MARK: - DSL 风格封装（链式）
extension JobsNetworkDataReadyMonitor {
    @discardableResult
    func byWaitOnce(
        interval: TimeInterval = 0.5,
        timeout: TimeInterval? = 10,
        onWiFiReady: (() -> Void)? = nil,
        onCellularReady: (() -> Void)? = nil,
        onTimeout: (() -> Void)? = nil
    ) -> Self {
        waitOnce(
            interval: interval,
            timeout: timeout,
            onWiFiReady: onWiFiReady,
            onCellularReady: onCellularReady,
            onTimeout: onTimeout
        )
        return self
    }
}
/// 统一入口：等待 Wi-Fi / 蜂窝“真的有流量”
///
/// - 默认 interval = 0.5s, timeout = 10s；
/// - 哪个 block 不关心就传 nil。
///
/// 示例：
/// ```swift
/// jobsWaitNetworkDataReady(
///     onWiFiReady: {
///         print("✅ Wi-Fi 有真实流量了")
///     },
///     onCellularReady: {
///         print("✅ 蜂窝有真实流量了，可以放心走付费流量逻辑")
///     },
///     onTimeout: {
///         print("⏰ 一直没探测到流量（可能请求失败或者网络环境很奇怪）")
///     }
/// )
/// ```
func jobsWaitNetworkDataReady(
    onWiFiReady: (() -> Void)? = nil,
    onCellularReady: (() -> Void)? = nil,
    onTimeout: (() -> Void)? = nil
) {
    JobsNetworkDataReadyMonitor.shared.byWaitOnce(
        interval: 0.5,
        timeout: 10,
        onWiFiReady: onWiFiReady,
        onCellularReady: onCellularReady,
        onTimeout: onTimeout
    )
}
