//
//  SplashAdManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/21.
//

import Foundation
import BUAdSDK
import UIKit

// MARK: - 回调类型定义
typealias SplashAdLoadCallback = (Result<Void, Error>) -> Void
typealias SplashAdShowCallback = (SplashAdEvent) -> Void

// MARK: - 广告事件枚举
enum SplashAdEvent {
    case loadSuccess
    case loadFailed(Error)
    case willShow
    case didShow
    case showFailed(Error)
    case clicked
    case closed(closeType: String)
    case renderSuccess
    case renderFailed(Error)
    case videoPlayFinished
    case videoPlayFailed(Error)
}

class SplashAdManager: NSObject, ObservableObject {
    static let shared = SplashAdManager()
    
    // MARK: - 属性
    private var splashAd: BUSplashAd?
    private var currentAdSlotId: String?
    
    // 状态发布
    @Published var isLoading = false
    @Published var hasShown = false
    @Published var isAdReady = false
    
    // 状态控制
    private var shouldShowSplashAd = true
    private var hasShownThisSession = false
    private var isInSplashView = true
    private var isDestroyed = false
    
    // 回调存储
    private var loadCallback: SplashAdLoadCallback?
    private var eventCallback: SplashAdShowCallback?
    
    override private init() {
        super.init()
        Logger.info("SplashAdManager 初始化", category: .adSlot)
    }
    
    // MARK: - 公共方法
    
    /// 设置事件回调
    func setEventCallback(_ callback: @escaping SplashAdShowCallback) {
        self.eventCallback = callback
    }
    
    /// 重置会话状态
    func resetSessionState() {
        guard !isDestroyed else { return }
        
        hasShownThisSession = false
        shouldShowSplashAd = true
        isInSplashView = true
        isAdReady = false
        currentAdSlotId = nil
        loadCallback = nil
        eventCallback = nil
        
        Logger.info("重置开屏广告会话状态", category: .adSlot)
    }
    
    /// 设置是否在启动页中
    func setInSplashView(_ inSplash: Bool) {
        if isInSplashView == inSplash { return }
        
        isInSplashView = inSplash
        Logger.info("设置启动页状态: \(inSplash ? "在启动页" : "已离开启动页")", category: .adSlot)
        
        if !inSplash {
            shouldShowSplashAd = false
        }
    }
    
    /// 禁用开屏广告展示
    func disableSplashAd() {
        guard !isDestroyed else { return }
        
        shouldShowSplashAd = false
        Logger.info("禁用开屏广告展示", category: .adSlot)
    }
    
    /// 加载开屏广告
    func loadSplashAd(completion: SplashAdLoadCallback? = nil) {
        guard !isDestroyed else {
            Logger.warning("广告管理器已销毁，跳过加载", category: .adSlot)
            completion?(.failure(NSError(domain: "SplashAdManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "管理器已销毁"])))
            return
        }
        
        Logger.info("开始加载开屏广告...", category: .adSlot)
        
        guard shouldShowSplashAd && !hasShownThisSession && isInSplashView else {
            let errorMsg = "不满足展示条件 - shouldShow: \(shouldShowSplashAd), hasShown: \(hasShownThisSession), inSplash: \(isInSplashView)"
            Logger.warning(errorMsg, category: .adSlot)
            let error = NSError(domain: "SplashAdManager", code: -2, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            completion?(.failure(error))
            return
        }
        
        guard !isLoading else {
            Logger.info("开屏广告正在加载中，跳过重复请求", category: .adSlot)
            return
        }
        
        // 获取动态广告位ID
        guard let adSlotId = AdSlotManager.shared.getCurrentSplashAdSlotId() else {
            let errorMsg = "未找到开屏广告位ID"
            Logger.warning(errorMsg, category: .adSlot)
            let error = NSError(domain: "SplashAdManager", code: -3, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            completion?(.failure(error))
            return
        }
        
        currentAdSlotId = adSlotId
        loadCallback = completion
        
        Logger.info("使用广告位ID: \(adSlotId)", category: .adSlot)
        
        isLoading = true
        isAdReady = false
        
        let slot = BUAdSlot()
        slot.id = adSlotId
        
        splashAd = BUSplashAd(slot: slot, adSize: UIScreen.main.bounds.size)
        splashAd?.delegate = self
        splashAd?.loadData()
    }
    
    /// 手动展示广告
    @discardableResult
    func showSplashAd() -> Bool {
        guard !isDestroyed else {
            Logger.warning("广告管理器已销毁，无法展示", category: .adSlot)
            return false
        }
        
        Logger.info("尝试展示开屏广告...", category: .adSlot)
        
        guard canShowAd(), isAdReady, let ad = splashAd else {
            Logger.warning("无法展示广告 - canShow: \(canShowAd()), isReady: \(isAdReady), hasAd: \(splashAd != nil)", category: .adSlot)
            return false
        }
        
        guard let rootViewController = UIUtils.findViewController() else {
            Logger.error("无法获取根视图控制器", category: .adSlot)
            return false
        }
        
        // 检查当前是否有其他present操作进行中
        if rootViewController.presentedViewController != nil {
            Logger.info("当前已有presented的ViewController，延迟展示广告", category: .adSlot)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                _ = self.showSplashAd()
            }
            return true
        }
        
        hasShownThisSession = true
        Logger.info("开始present开屏广告ViewController", category: .adSlot)
        Logger.info("当前rootViewController: \(type(of: rootViewController))", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        ad.showSplashView(inRootViewController: rootViewController)
        return true
    }
    
    /// 手动销毁广告
    func destroyAd() {
        guard !isDestroyed else {
            Logger.info("广告已被销毁，跳过重复销毁", category: .adSlot)
            return
        }
        
        Logger.info("手动销毁开屏广告", category: .adSlot)
        splashAd?.mediation?.destoryAd()
        splashAd = nil
        currentAdSlotId = nil
        loadCallback = nil
        eventCallback = nil
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.isAdReady = false
        }
        
        isDestroyed = true
    }
    
    // MARK: - 私有方法
    
    private func canShowAd() -> Bool {
        return shouldShowSplashAd && !hasShownThisSession && isInSplashView && !isDestroyed
    }
    
    private func notifyEvent(_ event: SplashAdEvent) {
        DispatchQueue.main.async {
            self.eventCallback?(event)
        }
    }
    
    private func executeLoadCallback(_ result: Result<Void, Error>) {
        DispatchQueue.main.async {
            self.loadCallback?(result)
            self.loadCallback = nil
        }
    }
}

// MARK: - BUSplashAdDelegate
extension SplashAdManager: BUSplashAdDelegate {
    
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        Logger.success("开屏广告加载成功，等待手动展示", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.isAdReady = true
        }
        
        guard canShowAd() else {
            Logger.warning("加载成功但不满足展示条件，销毁广告", category: .adSlot)
            let error = NSError(domain: "SplashAdManager", code: -4, userInfo: [NSLocalizedDescriptionKey: "展示条件已变化"])
            executeLoadCallback(.failure(error))
            destroyAd()
            return
        }
        
        executeLoadCallback(.success(()))
        notifyEvent(.loadSuccess)
    }
    
    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        let errorMessage = error?.localizedDescription ?? "未知错误"
        Logger.error("开屏广告加载失败: \(error?.code ?? 0) \(errorMessage)", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.isAdReady = false
        }
        
        let adError = error ?? BUAdError()
        executeLoadCallback(.failure(adError))
        notifyEvent(.loadFailed(adError))
    }
    
    func splashAdWillShow(_ splashAd: BUSplashAd) {
        Logger.info("开屏广告即将展示", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        if !isInSplashView {
            Logger.warning("广告展示时已不在启动页", category: .adSlot)
        }
        
        notifyEvent(.willShow)
    }
    
    func splashAdDidShow(_ splashAd: BUSplashAd) {
        Logger.success("开屏广告已展示", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        DispatchQueue.main.async {
            self.hasShown = true
        }
        
        notifyEvent(.didShow)
    }
    
    func splashAdDidClick(_ splashAd: BUSplashAd) {
        Logger.info("用户点击了开屏广告", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        notifyEvent(.clicked)
    }
    
    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        Logger.info("开屏广告关闭，关闭类型: \(closeType.rawValue)", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        let closeTypeName: String
        switch closeType {
        case .clickSkip: closeTypeName = "点击跳过"
        case .clickAd: closeTypeName = "点击广告"
        case .countdownToZero: closeTypeName = "倒计时结束"
        case .unknow: closeTypeName = "未知"
        case .forceQuit: closeTypeName = "强制退出"
        @unknown default: closeTypeName = "其他方式"
        }
        
        Logger.info("关闭方式: \(closeTypeName)", category: .adSlot)
        
        // 清理广告对象
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
        
        DispatchQueue.main.async {
            self.hasShown = true
            self.isLoading = false
            self.isAdReady = false
        }
        
        shouldShowSplashAd = false
        notifyEvent(.closed(closeType: closeTypeName))
    }
    
    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
        Logger.error("开屏广告展示失败: \(error.localizedDescription)", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
        
        DispatchQueue.main.async {
            self.isLoading = false
            self.isAdReady = false
        }
        
        notifyEvent(.showFailed(error))
    }
    
    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
        Logger.success("开屏广告渲染完成", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        notifyEvent(.renderSuccess)
    }
    
    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        let errorMessage = error?.localizedDescription ?? "未知渲染错误"
        Logger.error("开屏广告渲染失败: \(errorMessage)", category: .adSlot)
        Logger.info("广告位ID: \(currentAdSlotId ?? "未知")", category: .adSlot)
        
        let adError = error ?? BUAdError()
        notifyEvent(.renderFailed(adError))
    }
    
    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        Logger.info("开屏广告控制器被关闭", category: .adSlot)
    }
    
    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        let interactionTypeName: String
        switch interactionType {
        case .custorm: interactionTypeName = "自定义交互"
        case .URL: interactionTypeName = "浏览器打开网页"
        case .page: interactionTypeName = "应用内打开网页"
        case .download: interactionTypeName = "下载应用"
        case .videoAdDetail: interactionTypeName = "视频广告详情页"
        case .mediationOthers: interactionTypeName = "聚合其他广告SDK"
        @unknown default: interactionTypeName = "未知交互类型"
        }
        
        Logger.info("其他控制器被关闭，交互类型: \(interactionTypeName)", category: .adSlot)
    }
    
    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        if let error = error {
            Logger.error("开屏视频广告播放失败: \(error.localizedDescription)", category: .adSlot)
            notifyEvent(.videoPlayFailed(error))
        } else {
            Logger.success("开屏视频广告播放完成", category: .adSlot)
            notifyEvent(.videoPlayFinished)
        }
    }
}
