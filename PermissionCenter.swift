//
//  PermissionCenter.swift
//  Drop-in utility for iOS system permissions
//

import UIKit
import Photos
import AVFoundation
import AVFAudio
import CoreLocation
import CoreBluetooth
// ================================== 权限中心：声明 ==================================
public enum SystemPermission {
    case camera
    case photoLibraryReadWrite
    case microphone
    case locationWhenInUse
    case bluetooth
}

public enum PermissionState {
    case authorized
    case denied
    case notDetermined
    case restricted
    case limited                     // 仅对相册有意义
}
// ================================== 权限中心：实现 ==================================
public final class PermissionCenter: NSObject {
    // 私有：主线程保障
    @inline(__always)
    private static func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread { block() } else { DispatchQueue.main.async { block() } }
    }
    // 统一对外入口
    public static func ensure(_ permission: SystemPermission,
                              from presenter: UIViewController?,
                              onAuthorized: @escaping () -> Void) {
        switch permission {
        case .camera:               ensureCamera(from: presenter, onAuthorized: onAuthorized)
        case .photoLibraryReadWrite:ensurePhotoLibrary(from: presenter, onAuthorized: onAuthorized)
        case .microphone:           ensureMicrophone(from: presenter, onAuthorized: onAuthorized)
        case .locationWhenInUse:    ensureLocationWhenInUse(from: presenter, onAuthorized: onAuthorized)
        case .bluetooth:            ensureBluetooth(from: presenter, onAuthorized: onAuthorized)
        }
    }
    // MARK: Camera
    private static func ensureCamera(from presenter: UIViewController?, onAuthorized: @escaping () -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            onMain { onAuthorized() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                granted ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
            }
        case .denied, .restricted:
            showNoPermissionToast(in: presenter)
        @unknown default:
            showNoPermissionToast(in: presenter)
        }
    }
    // MARK: Photo Library (readWrite)
    private static func ensurePhotoLibrary(from presenter: UIViewController?, onAuthorized: @escaping () -> Void) {
        if #available(iOS 14, *) {
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited:
                onMain { onAuthorized() }   // limited 也放行
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    switch newStatus {
                    case .authorized, .limited: onMain { onAuthorized() }
                    default: showNoPermissionToast(in: presenter)
                    }
                }
            case .denied, .restricted:
                showNoPermissionToast(in: presenter)
            @unknown default:
                showNoPermissionToast(in: presenter)
            }
        } else {
            let status = PHPhotoLibrary.authorizationStatus()
            switch status {
            case .authorized:
                onMain { onAuthorized() }
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization { newStatus in
                    newStatus == .authorized ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
                }
            default:
                showNoPermissionToast(in: presenter)
            }
        }
    }
    // MARK: Microphone  ✅ iOS 17+
    private static func ensureMicrophone(from presenter: UIViewController?, onAuthorized: @escaping () -> Void) {
        if #available(iOS 17.0, *) {
            let p = AVAudioApplication.shared.recordPermission
            switch p {
            case .granted:
                onMain { onAuthorized() }
            case .undetermined:
                AVAudioApplication.requestRecordPermission { granted in
                    granted ? onMain {onAuthorized()} : showNoPermissionToast(in: presenter)
                }
            case .denied:
                showNoPermissionToast(in: presenter)
            @unknown default:
                showNoPermissionToast(in: presenter)
            }
        } else {
            let p = AVAudioSession.sharedInstance().recordPermission
            switch p {
            case .granted:
                onMain { onAuthorized() }
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    granted ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
                }
            case .denied:
                showNoPermissionToast(in: presenter)
            @unknown default:
                showNoPermissionToast(in: presenter)
            }
        }
    }
    // MARK: Location (WhenInUse)  ✅ iOS 14+
    private static var locProxy = LocationProxy()
    private static func ensureLocationWhenInUse(from presenter: UIViewController?, onAuthorized: @escaping () -> Void) {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = CLLocationManager().authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            onMain { onAuthorized() }
        case .notDetermined:
            locProxy.requestWhenInUse { granted in
                granted ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
            }
        case .denied, .restricted:
            showNoPermissionToast(in: presenter)
        @unknown default:
            showNoPermissionToast(in: presenter)
        }
    }
    // MARK: Bluetooth
    private static var btProxy = BluetoothProxy()
    private static func ensureBluetooth(from presenter: UIViewController?, onAuthorized: @escaping () -> Void) {
        if #available(iOS 13.1, *) {
            let auth = CBCentralManager.authorization
            switch auth {
            case .allowedAlways:
                onMain { onAuthorized() }
            case .notDetermined:
                btProxy.request { granted in
                    granted ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
                }
            case .denied, .restricted:
                showNoPermissionToast(in: presenter)
            @unknown default:
                showNoPermissionToast(in: presenter)
            }
        } else {
            btProxy.request { granted in
                granted ? onMain { onAuthorized() } : showNoPermissionToast(in: presenter)
            }
        }
    }
    // MARK: Toast
    private static func showNoPermissionToast(in presenter: UIViewController?) {
        Task { @MainActor in
            toastBy("请获取相关权限")
        }
    }
}
// ================================== 私有代理：定位 & 蓝牙 ==================================
private final class LocationProxy: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var completion: ((Bool) -> Void)?

    func requestWhenInUse(_ completion: @escaping (Bool)->Void) {
        self.completion = completion
        let m = CLLocationManager()
        self.manager = m
        m.delegate = self
        m.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handle(manager.authorizationStatus)
    }

    @available(iOS, introduced: 4.2, deprecated: 14.0)
    func locationManager(_ manager: CLLocationManager,
                         didChangeAuthorization status: CLAuthorizationStatus) {
        handle(status)
    }

    private func handle(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: completion?(true)
        case .denied, .restricted:                   completion?(false)
        case .notDetermined:                          return
        @unknown default:                             completion?(false)
        }
        completion = nil
        manager?.delegate = nil
        manager = nil
    }
}

private final class BluetoothProxy: NSObject, CBCentralManagerDelegate {
    private var central: CBCentralManager?
    private var completion: ((Bool)->Void)?

    func request(_ completion: @escaping (Bool)->Void) {
        self.completion = completion
        self.central = CBCentralManager(delegate: self, queue: nil,
                                        options: [CBCentralManagerOptionShowPowerAlertKey: false])
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let granted: Bool
        if #available(iOS 13.1, *) {
            granted = (CBCentralManager.authorization == .allowedAlways)
        } else {
            granted = (central.state != .unauthorized && central.state != .unsupported)
        }
        completion?(granted)
        completion = nil
        self.central?.delegate = nil
        self.central = nil
    }
}
