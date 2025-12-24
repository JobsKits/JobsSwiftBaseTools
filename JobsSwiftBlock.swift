//
//  JobsSwiftBlock.swift
//  JobsSwiftBaseConfigDemo
//
//  Created by Jobs on 12/5/25.
//

#if os(OSX)
import AppKit
#elseif os(iOS) || os(tvOS)
import UIKit
#endif
import WebKit
import ObjectiveC
// MARK: —— CreatedBy@Jobs
/// 全局@基础
public typealias jobsByVoidBlock = () -> Void
public typealias jobsByAnyBlock = (Any?) -> Void
public typealias jobsByTypeBlock<T> = (T?) -> Void

public typealias jobsByNonNullTypeBlock<T> = (T) -> Void
public typealias jobsByOwnerArgBlock<Owner, Arg> = (Owner, Arg) -> Void
public typealias jobsByOwnerRetBlock<Owner, R> = (Owner) -> R
public typealias jobsByOwnerArgRetBlock<Owner, Arg, R> = (Owner, Arg) -> R
public typealias jobsByArgBlock<Arg> = (Arg) -> Void
public typealias JobsRetOptionalTByVoidBlock<T> = () -> T?
public typealias JobsRetOptionalTByArgBlock<Arg, T> = (Arg) -> T?
public typealias jobsByCurriedOwnerRetBlock<Owner, R> = (Owner) -> () -> R
public typealias jobsByCurriedOwnerArgRetBlock<Owner, Arg, R> = (Owner) -> (Arg) -> R

public typealias jobsByBoolBlock = (Bool?) -> Void
public typealias jobsByBOOLBlock = (Bool) -> Void

public typealias jobsByintBlock = (Int?) -> Void
public typealias jobsByIntBlock = (Int) -> Void

public typealias jobsBycgFloatBlock = (CGFloat?) -> Void
public typealias jobsByCGFloatBlock = (CGFloat) -> Void

public typealias jobsByCGRectBlock = (CGRect?) -> Void
public typealias jobsByFrameBlock = (CGRect) -> Void
public typealias jobsByCGPointBlock = (CGPoint?) -> Void
public typealias jobsByPointBlock = (CGPoint) -> Void
public typealias jobsByCGSizeBlock = (CGSize?) -> Void
public typealias jobsBySizeBlock = (CGSize) -> Void

public typealias jobsByURLBlock = (URL?) -> Void
public typealias jobsByUrlBlock = (URL) -> Void
public typealias jobsByURLsBlock = ([URL]?) -> Void
public typealias jobsByUrlsBlock = ([URL]) -> Void
public typealias jobsByStringBlock = (String?) -> Void
public typealias jobsByStrBlock = (String) -> Void
public typealias jobsByButtonBlock = (UIButton?) -> Void
public typealias jobsByBtnBlock = (UIButton) -> Void
public typealias jobsByBarButtonItemBlock = (UIBarButtonItem?) -> Void
public typealias jobsByBarBtnItemBlock = (UIBarButtonItem) -> Void
public typealias jobsByGestureRecognizerBlock = (UIGestureRecognizer?) -> Void
public typealias jobsByGRBlock = (UIGestureRecognizer) -> Void
public typealias jobsByNumberFormatterBlock = (NumberFormatter) -> Void
public typealias jobsByNavigationBarAppearanceBlock = (UINavigationBarAppearance) -> Void
public typealias jobsByBarButtonItemAppearanceBlock = (UIBarButtonItemAppearance) -> Void
public typealias jobsByNavigationPolicyBlock = (WKNavigationActionPolicy) -> Void
public typealias jobsByCATransitionBlock = (CATransition) -> Void
public typealias jobsByCAAnimationBlock = (CAAnimation) -> Void
public typealias jobsByUIViewBlock = (UIView?) -> Void
public typealias jobsByViewBlock = (UIView) -> Void
public typealias jobsByUIContextMenuInteractionBlock = (UIContextMenuInteraction?) -> Void
public typealias jobsByContextMenuInteractionBlock = (UIContextMenuInteraction) -> Void
public typealias JobsYTKProgress = (_ progress: Progress) -> Void
public typealias jobsByOpenResultBlock = (JobsOpenResult) -> Void

public typealias jobsByAnyStringBlock = (Any?, String?) -> Void
public typealias MobileActionBlock = (_ body: [String: Any], _ reply: jobsByAnyBlock) -> Void
public typealias NativeBlock = (_ payload: Any?, _ reply: @escaping jobsByAnyBlock) -> Void

public typealias JobsRetStringByCGFloatBlock = (CGFloat) -> String
/// 全局@泛型
public typealias JobsRetTByVoidBlock<T> = () -> T
/// 全局@inout
public typealias jobsByInoutListContentConfigBlock = (inout UIListContentConfiguration) -> Void
public typealias jobsByInoutBackgroundConfigurationBlock = (inout UIBackgroundConfiguration) -> Void
public typealias jobsByInoutWKWebConfigBlock = (inout WKWebViewConfiguration) -> Void
/// 全局@MainActor
public typealias JobsByAnyErrMASendableBlock = @MainActor @Sendable (Any?, Error?) -> Void
public typealias JobsByTMASendableBlock<T: Sendable> = @MainActor @Sendable (T) -> Void
public typealias JobsByMAVoidBlock = @MainActor () -> Void


/// UI@输入控件
/// 限长状态变化时的回调
/// isLimited = true  : 进入“被限长”状态（尝试超出时被拦截）
/// isLimited = false : 从“被限长”状态恢复（删到 maxLength 以下）
public typealias JobsTFOnLimitChanged = (_ isLimited: Bool, _ textField: UITextField) -> Void
public typealias UITextFieldOnChange = (_ tf: UITextField,
                                        _ input: String,
                                        _ oldText: String,
                                        _ isDeleting: Bool) -> Void
public typealias TVOnBackspace = (_ tv: UITextView) -> Void
public typealias TVOnChange = (_ tv: UITextView,
                               _ input: String,
                               _ old: String,
                               _ isDeleting: Bool) -> Void
/// UI@UIButton
public typealias BackButtonProvider = () -> UIButton?         // 返回 nil 隐藏
public typealias BackButtonLayout = (JobsNavBar, UIButton, ConstraintMaker) -> Void

public typealias JobsButtonLongPressBlock = (UIButton, UILongPressGestureRecognizer) -> Void
public typealias TimerStateChangeHandler = (_ button: UIButton,
                                            _ oldState: TimerState,
                                            _ newState: TimerState) -> Void
/// UI@富文本
public typealias JobsRetAttributedString = () -> NSAttributedString?    // 返回 nil 隐藏
/// UI@其他
public typealias JobsRetByListContentConfigBlock = (UIListContentConfiguration) -> UIListContentConfiguration
public typealias JobsRetViewsByVoidBlock = () -> [UIView]
/// Data@网络请求
public typealias JobsRetStringByURLRequestBlock = (URLRequest) -> String?
// MARK: —— Cocoapods
/// Cocoapods@Kingfisher
#if canImport(Kingfisher)
import Kingfisher
public typealias KFCompleted = (Result<RetrieveImageResult, KingfisherError>) -> Void
#else
// 没有集成 Kingfisher 时给一个退化版本，避免整个工程编不过
public typealias KFCompleted = (Result<UIImage, Error>) -> Void
#endif
/// Cocoapods@SnapKit
#if canImport(SnapKit)
import SnapKit
/// SnapKit 语法糖🍬
// 存的就是这个类型
public typealias jobsByConstraintMakerBlock = (_ make: ConstraintMaker) -> Void
#endif
/// Cocoapods@YTKNetwork
#if canImport(YTKNetwork)
import YTKNetwork
public typealias JobsYTKBatchJobsVoidBlock = (_ batch: YTKBatchRequest) -> Void
public typealias JobsYTKJobsVoidBlock = (_ request: YTKBaseRequest) -> Void
public typealias JobsYTKChainSuccess = (_ chain: YTKChainRequest) -> Void
public typealias JobsYTKChainFailure = (_ chain: YTKChainRequest,
                                        _ failedRequest: YTKBaseRequest) -> Void
public typealias JobsYTKChainStepCallback = (_ chain: YTKChainRequest,
                                             _ finishedRequest: YTKBaseRequest) -> Void
#endif
/// Cocoapods@Moya
#if canImport(Moya)
import Moya
public typealias jobsByMoyaResultBlock = (Result<Response, MoyaError>) -> Void
#endif
