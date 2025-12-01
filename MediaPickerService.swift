//
//  MediaPickerService.swift
//  Camera / Photos / Video record
//

import UIKit
import Photos
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers
import ObjectiveC.runtime

public final class MediaPickerService: NSObject {
    // ---------- 一键：相机 ----------
    public static func pickFromCamera(from presenter: UIViewController,
                                      allowsEditing: Bool = false,
                                      onImage: @escaping (UIImage) -> Void) {
        PermissionCenter.ensure(.camera, from: presenter) {
            guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                onMain {
                   toastBy("此设备不支持相机")
                };return
            }
            onMain {
                let proxy = CameraProxy(allowsEditing: allowsEditing, completion: onImage)
                let picker = UIImagePickerController()
                picker.sourceType = .camera
                picker.allowsEditing = allowsEditing
                picker.delegate = proxy
                attachProxy(proxy, to: presenter)
                presenter.present(picker, animated: true)
            }
        }
    }
    // ---------- 一键：系统相册（多选，默认 9） ----------
    public static func pickFromPhotoLibrary(from presenter: UIViewController,
                                            maxSelection: Int = 9,
                                            imagesOnly: Bool = true,
                                            onImages: @escaping ([UIImage]) -> Void) {
        PermissionCenter.ensure(.photoLibraryReadWrite, from: presenter) {
            onMain {
                if #available(iOS 14, *) {
                    var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
                    config.selectionLimit = maxSelection <= 0 ? 0 : maxSelection // 0=不限制
                    config.filter = imagesOnly ? .images : .any(of: [.images, .livePhotos, .videos])
                    let proxy = PHPickerProxy(completion: onImages)
                    let picker = PHPickerViewController(configuration: config)
                    picker.delegate = proxy
                    attachProxy(proxy, to: presenter)
                    presenter.present(picker, animated: true)
                } else {
                    guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
                    let proxy = LegacyLibraryProxy(acceptsImagesOnly: imagesOnly) { img in
                        onImages(img.map { [$0] } ?? [])
                    }
                    let picker = UIImagePickerController()
                    picker.sourceType = .photoLibrary
                    picker.allowsEditing = false
                    picker.delegate = proxy
                    attachProxy(proxy, to: presenter)
                    presenter.present(picker, animated: true)
                }
            }
        }
    }
    // ---------- 一键：录制视频 ----------
    public static func recordVideo(from presenter: UIViewController,
                                   maxDuration: TimeInterval = 30,
                                   quality: UIImagePickerController.QualityType = .typeHigh,
                                   onVideoURL: @escaping (URL) -> Void) {
        // 依次确认相机 + 麦克风
        PermissionCenter.ensure(.camera, from: presenter) {
            PermissionCenter.ensure(.microphone, from: presenter) {

                guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
                    toastBy("此设备不支持相机")
                    return
                }
                // 1) 能力检查：是否支持录视频 UTI
                let movieUTI: String = {
                    if #available(iOS 14.0, *) { return UTType.movie.identifier } // "public.movie"
                    else { return "public.movie" }
                }()
                let supported = UIImagePickerController.availableMediaTypes(for: .camera) ?? []
                guard supported.contains(movieUTI) else {
                    toastBy("此设备不支持视频录制")
                    return
                }
                // 2) 能力检查：哪个摄像头支持 video
                let chooseDevice: UIImagePickerController.CameraDevice? = {
                    func supportsVideo(_ device: UIImagePickerController.CameraDevice) -> Bool {
                        guard UIImagePickerController.isCameraDeviceAvailable(device),
                              let modes = UIImagePickerController.availableCaptureModes(for: device) else {
                            return false
                        }
                        // modes: [NSNumber]，对比 CameraCaptureMode.video 的 rawValue
                        return modes.contains { $0.intValue == UIImagePickerController.CameraCaptureMode.video.rawValue }
                        // 或者：
                        // return modes.compactMap { UIImagePickerController.CameraCaptureMode(rawValue: $0.intValue) }
                        //            .contains(.video)
                    }

                    if supportsVideo(.rear)  { return .rear }
                    if supportsVideo(.front) { return .front }
                    return nil
                }()
                guard let device = chooseDevice else {
                    Task{
                        @MainActor in
                        toastBy("未检测到可用摄像头用于录制")
                    };return
                }
                // 3) 顺序很重要：先 mediaTypes，后 cameraCaptureMode
                onMain {
                    let proxy = VideoCameraProxy { url in onVideoURL(url) }
                    let picker = UIImagePickerController()
                    picker.sourceType = .camera
                    picker.cameraDevice = device
                    if #available(iOS 14.0, *) {
                        picker.mediaTypes = [UTType.movie.identifier]   // ✅ 先设类型
                    } else {
                        picker.mediaTypes = ["public.movie"]
                    }
                    picker.videoQuality = quality
                    picker.videoMaximumDuration = maxDuration
                    picker.cameraCaptureMode = .video                   // ✅ 再切视频模式
                    picker.delegate = proxy
                    attachProxy(proxy, to: presenter)
                    presenter.present(picker, animated: true)
                }
            }
        }
    }
}
// ================================== 代理们 ==================================
// 相机拍照
private final class CameraProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let allowsEditing: Bool
    let completion: (UIImage) -> Void

    init(allowsEditing: Bool, completion: @escaping (UIImage)->Void) {
        self.allowsEditing = allowsEditing
        self.completion = completion
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let key: UIImagePickerController.InfoKey = allowsEditing ? .editedImage : .originalImage
        if let img = info[key] as? UIImage { completion(img) }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
// iOS 14+ 相册多选
@available(iOS 14, *)
private final class PHPickerProxy: NSObject, PHPickerViewControllerDelegate {
    let completion: ([UIImage]) -> Void
    init(completion: @escaping ([UIImage])->Void) { self.completion = completion }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard !results.isEmpty else { completion([]); return }

        var images = [UIImage]()
        let group = DispatchGroup()

        for r in results {
            let provider = r.itemProvider
            if provider.canLoadObject(ofClass: UIImage.self) {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { obj, _ in
                    if let img = obj as? UIImage { images.append(img) }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [completion] in completion(images) }
    }
}
// 老系统相册（单选）
private final class LegacyLibraryProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let acceptsImagesOnly: Bool
    let completion: (UIImage?) -> Void

    init(acceptsImagesOnly: Bool, completion: @escaping (UIImage?) -> Void) {
        self.acceptsImagesOnly = acceptsImagesOnly
        self.completion = completion
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let img = info[.originalImage] as? UIImage
        completion(img)
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        completion(nil)
        picker.dismiss(animated: true)
    }
}
// 录像
private final class VideoCameraProxy: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let completion: (URL) -> Void
    init(completion: @escaping (URL) -> Void) { self.completion = completion }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let url = info[.mediaURL] as? URL { completion(url) }
        picker.dismiss(animated: true)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
// ================================== AO：把代理挂到 VC 防止释放 ==================================
private enum _JobsAssocKeys {
    static var mediaPickerProxy = UInt8(0)
}

private func attachProxy(_ proxy: AnyObject, to host: UIViewController) {
    objc_setAssociatedObject(host, &_JobsAssocKeys.mediaPickerProxy, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
}
// ================================== VC 便利方法 ==================================
public extension NSObject {
    /// 一键：相机拍照
    func pickFromCamera(allowsEditing: Bool = false,
                        onImage: @escaping (UIImage) -> Void) {
        MediaPickerService.pickFromCamera(from: UIApplication.jobsTopMostVC()!, allowsEditing: allowsEditing, onImage: onImage)
    }
    /// 一键：相册选图（默认最多 9 张；传 0 表示不限制）
    func pickFromPhotoLibrary(maxSelection: Int = 9,
                              imagesOnly: Bool = true,
                              onImages: @escaping ([UIImage]) -> Void) {
        MediaPickerService.pickFromPhotoLibrary(from: UIApplication.jobsTopMostVC()!,
                                                maxSelection: maxSelection,
                                                imagesOnly: imagesOnly,
                                                onImages: onImages)
    }
    /// 一键：录制视频
    func recordVideo(maxDuration: TimeInterval = 30,
                     quality: UIImagePickerController.QualityType = .typeHigh,
                     onVideoURL: @escaping (URL) -> Void) {
        MediaPickerService.recordVideo(from: UIApplication.jobsTopMostVC()!,
                                       maxDuration: maxDuration,
                                       quality: quality,
                                       onVideoURL: onVideoURL)
    }
}
