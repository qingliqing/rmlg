//
//  SplashAdManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/21.
//

import Foundation
import BUAdSDK
import UIKit

class SplashAdManager: NSObject, ObservableObject {
    static let shared = SplashAdManager()
    
    // MARK: - 属性
    private var splashAd: BUSplashAd?
    
    // 广告位ID - 替换为你的真实广告位ID
    private let adSlotID = "103508882" // 这是示例ID，请替换为真实ID
    
    // 状态发布
    @Published var isLoading = false
    @Published var hasShown = false
    
    override private init() {
        super.init()
    }
    
    // MARK: - 公共方法
    
    /// 加载开屏广告
    func loadSplashAd() {
        print("🌅 开始加载开屏广告...")
        
        guard !isLoading else {
            print("⚠️ 开屏广告正在加载中，跳过重复请求")
            return
        }
        
        isLoading = true
        
        // 创建广告位配置
        let slot = BUAdSlot()
        slot.id = adSlotID
        
        // 创建开屏广告
        splashAd = BUSplashAd(slot: slot, adSize: UIScreen.main.bounds.size)
        splashAd?.delegate = self
        
        // 开始加载广告
        splashAd?.loadData()
    }
    
    /// 手动销毁广告
    func destroyAd() {
        print("🗑️ 手动销毁开屏广告")
        splashAd?.mediation?.destoryAd()
        splashAd = nil
        isLoading = false
    }
    
    // MARK: - 私有方法
    
    /// 获取根视图控制器
    private func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: \.isKeyWindow) else {
            print("🗑️ 根视图控制器获取失败")
            return nil
        }
        return window.rootViewController ?? window.rootViewController?.children.first
    }
    
    /// 通知广告事件
    private func postNotification(_ name: Notification.Name, userInfo: [String: Any]? = nil) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: name, object: nil, userInfo: userInfo)
        }
    }
}

// MARK: - BUSplashAdDelegate
extension SplashAdManager: BUSplashAdDelegate {
    
    // 加载成功
    func splashAdLoadSuccess(_ splashAd: BUSplashAd) {
        print("✅ 开屏广告加载成功")
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
        
        // 获取根视图控制器并显示广告
        guard let rootViewController = getRootViewController() else {
            print("❌ 无法获取根视图控制器，无法显示广告")
            postNotification(.splashAdLoadFailed, userInfo: ["error": "无法获取根视图控制器"])
            return
        }
        
        print("📱 开始显示开屏广告")
        splashAd.showSplashView(inRootViewController: rootViewController)
        
        postNotification(.splashAdLoadSuccess)
    }
    
    // 加载失败
    func splashAdLoadFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        let errorMessage = error?.localizedDescription ?? "未知错误"
        print("❌ 开屏广告加载失败:\(error?.code ?? 0) \(errorMessage)")
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
        
        postNotification(.splashAdLoadFailed, userInfo: ["error": errorMessage])
    }
    
    // 广告即将展示
    func splashAdWillShow(_ splashAd: BUSplashAd) {
        print("👀 开屏广告即将展示")
        postNotification(.splashAdWillShow)
    }
    
    // 广告被点击
    func splashAdDidClick(_ splashAd: BUSplashAd) {
        print("👆 用户点击了开屏广告")
        postNotification(.splashAdDidClick)
    }
    
    // 广告被关闭
    func splashAdDidClose(_ splashAd: BUSplashAd, closeType: BUSplashAdCloseType) {
        print("🔚 开屏广告关闭，关闭类型: \(closeType.rawValue)")
        
        let closeTypeName: String
        switch closeType {
        case .clickSkip:
            closeTypeName = "点击跳过"
        case .clickAd:
            closeTypeName = "点击广告"
        case .countdownToZero:
            closeTypeName = "倒计时结束"
        case .unknow:
            closeTypeName = "未知"
        case .forceQuit:
            closeTypeName = "强制退出"
        @unknown default:
            closeTypeName = "其他方式"
        }
        
        print("📱 关闭方式: \(closeTypeName)")
        
        // 销毁广告对象
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
        
        DispatchQueue.main.async {
            self.hasShown = true
            self.isLoading = false
        }
        
        postNotification(.splashAdDidClose, userInfo: ["closeType": closeTypeName])
    }
    
    // 广告展示失败
    func splashAdDidShowFailed(_ splashAd: BUSplashAd, error: Error) {
        let errorMessage = error.localizedDescription
        print("❌ 开屏广告展示失败: \(errorMessage)")
        
        // 销毁广告对象
        splashAd.mediation?.destoryAd()
        self.splashAd = nil
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
        
        postNotification(.splashAdShowFailed, userInfo: ["error": errorMessage])
    }
    
    // 广告渲染完成
    func splashAdRenderSuccess(_ splashAd: BUSplashAd) {
        print("🎨 开屏广告渲染完成")
        postNotification(.splashAdRenderSuccess)
    }
    
    // 广告渲染失败
    func splashAdRenderFail(_ splashAd: BUSplashAd, error: BUAdError?) {
        let errorMessage = error?.localizedDescription ?? "未知渲染错误"
        print("❌ 开屏广告渲染失败: \(errorMessage)")
        postNotification(.splashAdRenderFailed, userInfo: ["error": errorMessage])
    }
    
    // 广告展示
    func splashAdDidShow(_ splashAd: BUSplashAd) {
        print("👁️ 开屏广告已展示")
        
        DispatchQueue.main.async {
            self.hasShown = true
        }
        
        postNotification(.splashAdDidShow)
    }
    
    // 广告控制器被关闭
    func splashAdViewControllerDidClose(_ splashAd: BUSplashAd) {
        print("🔚 开屏广告控制器被关闭")
        postNotification(.splashAdViewControllerDidClose)
    }
    
    // 其他控制器被关闭
    func splashDidCloseOtherController(_ splashAd: BUSplashAd, interactionType: BUInteractionType) {
        let interactionTypeName: String
        switch interactionType {
        case .custorm:
            interactionTypeName = "自定义交互"
        case .URL:
            interactionTypeName = "浏览器打开网页"
        case .page:
            interactionTypeName = "应用内打开网页"
        case .download:
            interactionTypeName = "下载应用"
        case .videoAdDetail:
            interactionTypeName = "视频广告详情页"
        case .mediationOthers:
            interactionTypeName = "聚合其他广告SDK"
        @unknown default:
            interactionTypeName = "未知交互类型"
        }
        
        print("🔄 其他控制器被关闭，交互类型: \(interactionTypeName)")
        postNotification(.splashDidCloseOtherController, userInfo: ["interactionType": interactionTypeName])
    }
    
    // 视频播放完成
    func splashVideoAdDidPlayFinish(_ splashAd: BUSplashAd, didFailWithError error: Error?) {
        if let error = error {
            print("❌ 开屏视频广告播放失败: \(error.localizedDescription)")
            postNotification(.splashVideoPlayFailed, userInfo: ["error": error.localizedDescription])
        } else {
            print("🎬 开屏视频广告播放完成")
            postNotification(.splashVideoPlayFinished)
        }
    }
}

// MARK: - 通知名称扩展
extension Notification.Name {
    // 加载相关
    static let splashAdLoadSuccess = Notification.Name("splashAdLoadSuccess")
    static let splashAdLoadFailed = Notification.Name("splashAdLoadFailed")
    
    // 展示相关
    static let splashAdWillShow = Notification.Name("splashAdWillShow")
    static let splashAdDidShow = Notification.Name("splashAdDidShow")
    static let splashAdShowFailed = Notification.Name("splashAdShowFailed")
    
    // 渲染相关
    static let splashAdRenderSuccess = Notification.Name("splashAdRenderSuccess")
    static let splashAdRenderFailed = Notification.Name("splashAdRenderFailed")
    
    // 交互相关
    static let splashAdDidClick = Notification.Name("splashAdDidClick")
    static let splashAdDidClose = Notification.Name("splashAdDidClose")
    
    // 控制器相关
    static let splashAdViewControllerDidClose = Notification.Name("splashAdViewControllerDidClose")
    static let splashDidCloseOtherController = Notification.Name("splashDidCloseOtherController")
    
    // 视频相关
    static let splashVideoPlayFinished = Notification.Name("splashVideoPlayFinished")
    static let splashVideoPlayFailed = Notification.Name("splashVideoPlayFailed")
}
