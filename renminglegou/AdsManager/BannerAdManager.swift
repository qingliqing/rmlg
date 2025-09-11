//
//  BannerAdManager.swift
//  renminglegou
//
//  Created by Developer on 2025/8/27.
//

import SwiftUI
import UIKit
import BUAdSDK

// MARK: - Banner 广告管理器
final class BannerAdManager: NSObject, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var isLoaded = false
    @Published var errorMessage: String?
    @Published var adSize: CGSize = CGSize(width: 375, height: 160)
    
    // MARK: - Private Properties
    private var bannerView: BUNativeExpressBannerView?
    private var refreshTimer: Timer?
    private var rootViewController: UIViewController?
    private var isInitialized = false // 添加初始化状态标记
    private var lastLoadTime: TimeInterval = 0 // 添加上次加载时间
    private let minimumLoadInterval: TimeInterval = 5.0 // 最小加载间隔（秒）
    
    // MARK: - Configuration
    let slotId: String
    let refreshInterval: TimeInterval
    let defaultAdSize: CGSize
    
    // MARK: - Initialization
    init(slotId: String = "103585837",
         refreshInterval: TimeInterval = 30.0,
         defaultAdSize: CGSize = CGSize(width: 375, height: 160)) {
        self.slotId = slotId
        self.refreshInterval = refreshInterval
        self.defaultAdSize = defaultAdSize
        self.adSize = defaultAdSize
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// 加载Banner广告（带防重复调用逻辑）
    @MainActor
    func loadBannerAd(in viewController: UIViewController, containerSize: CGSize, force: Bool = false) {
        // 防止重复加载的检查
        let currentTime = Date().timeIntervalSince1970
        if !force && isLoading {
            print("Banner广告正在加载中，跳过重复请求")
            return
        }
        
        // 检查最小加载间隔
        if !force && currentTime - lastLoadTime < minimumLoadInterval {
            print("Banner广告加载间隔太短，跳过请求")
            return
        }
        
        // 如果已经有加载成功的广告且不是强制刷新，跳过
        if !force && isLoaded && bannerView != nil {
            print("Banner广告已加载，跳过重复请求")
            return
        }
        
        lastLoadTime = currentTime
        rootViewController = viewController
        
        print("开始加载Banner广告 - 强制: \(force), 容器尺寸: \(containerSize)")
        
        // 清理上次的广告
        cleanup()
        
        // 根据容器尺寸调整广告尺寸
        let adaptedSize = adaptAdSize(to: containerSize)
        adSize = adaptedSize
        
        isLoading = true
        errorMessage = nil
        
        // 创建广告位配置
        let slot = BUAdSlot()
        slot.id = AdSlotManager.shared.getCurrentBannerAdSlotId() ?? slotId
        
        // 创建Banner广告视图
        let bannerView = BUNativeExpressBannerView(
            slot: slot,
            rootViewController: viewController,
            adSize: adaptedSize
        )
        bannerView.delegate = self
        
        self.bannerView = bannerView
        bannerView.loadAdData()
        
        print("Banner广告开始加载，尺寸: \(adaptedSize)")
    }
    
    /// 初始化加载（仅调用一次）
    @MainActor
    func initializeAd(in viewController: UIViewController, containerSize: CGSize) {
        guard !isInitialized else {
            print("Banner广告已初始化，跳过重复初始化")
            return
        }
        
        isInitialized = true
        loadBannerAd(in: viewController, containerSize: containerSize, force: true)
        print("Banner广告完成初始化")
    }
    
    /// 获取当前的Banner视图
    func getBannerView() -> UIView? {
        return bannerView
    }
    
    /// 开始自动刷新
    @MainActor
    func startAutoRefresh() async {
        stopAutoRefresh()
        
        guard refreshInterval > 0 else {
            print("自动刷新间隔为0，不启动自动刷新")
            return
        }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                print("定时器触发广告刷新")
                await self.refreshAd()
            }
        }
        
        print("开始自动刷新Banner广告，间隔: \(refreshInterval)秒")
    }
    
    /// 停止自动刷新
    func stopAutoRefresh() {
        if refreshTimer != nil {
            print("停止Banner广告自动刷新")
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
    
    /// 手动刷新广告
    @MainActor
    func refreshAd() async {
        guard let viewController = rootViewController else {
            print("无法刷新广告：缺少根视图控制器")
            return
        }
        
        print("手动刷新Banner广告")
        let containerSize = CGSize(width: adSize.width, height: adSize.height)
        loadBannerAd(in: viewController, containerSize: containerSize, force: true)
    }
    
    /// 清理资源
    @MainActor
    func cleanup() {
        if let bannerView = bannerView {
            print("清理Banner广告视图")
            bannerView.removeFromSuperview()
            self.bannerView = nil
        }
        isLoaded = false
    }
    
    /// 重置状态（用于调试）
    @MainActor
    func resetState() {
        print("重置Banner广告管理器状态")
        stopAutoRefresh()
        cleanup()
        isInitialized = false
        lastLoadTime = 0
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// 根据容器尺寸自适应广告尺寸
    private func adaptAdSize(to containerSize: CGSize) -> CGSize {
        let screenWidth = UIScreen.main.bounds.width
        let maxWidth = min(containerSize.width, screenWidth)
        
        // 根据不同尺寸返回合适的广告尺寸
        switch maxWidth {
        case 0..<300:
            return CGSize(width: maxWidth, height: 100)
        case 300..<400:
            return CGSize(width: maxWidth, height: 150)
        default:
            // 保持宽高比约为 2.3:1
            let height = min(maxWidth / 2.3, 200)
            return CGSize(width: maxWidth, height: height)
        }
    }
    
    deinit {
        print("BannerAdManager 销毁")
        // deinit 中只能进行同步清理
        refreshTimer?.invalidate()
        refreshTimer = nil
        
        // 对于需要主线程的清理操作，我们使用 DispatchQueue
        DispatchQueue.main.async { [weak bannerView] in
            bannerView?.removeFromSuperview()
        }
    }
}

// MARK: - BUNativeExpressBannerViewDelegate
extension BannerAdManager: BUNativeExpressBannerViewDelegate {
    
    // 广告加载成功
    nonisolated func nativeExpressBannerAdViewDidLoad(_ bannerAdView: BUNativeExpressBannerView) {
        Task { @MainActor in
            print("✅ Banner广告加载成功")
            isLoading = false
            isLoaded = true
            errorMessage = nil
            
            // 更新实际广告尺寸
            adSize = bannerAdView.frame.size
            print("广告实际尺寸: \(adSize)")
        }
    }
    
    // 广告加载失败
    nonisolated func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
        Task { @MainActor in
            print("❌ Banner广告加载失败: \(error?.localizedDescription ?? "Unknown error")")
            isLoading = false
            isLoaded = false
            errorMessage = error?.localizedDescription ?? "广告加载失败"
        }
    }
    
    // 广告即将展示
    nonisolated func nativeExpressBannerAdViewWillBecomVisible(_ bannerAdView: BUNativeExpressBannerView) {
        Task { @MainActor in
            print("👀 Banner广告即将展示")
            // 只有在成功展示后才开始自动刷新，避免重复启动
            if refreshTimer == nil {
                await startAutoRefresh()
            }
            
            // 可以获取展示相关信息
            /*
            let info = bannerAdView.mediation?.getShowEcpmInfo()
            print("ecpm:\(info?.ecpm ?? "None")")
            print("platform:\(info?.adnName ?? "None")")
            print("ritID:\(info?.slotID ?? "None")")
            print("requestID:\(info?.requestID ?? "None")")
            */
        }
    }
    
    // 广告被点击
    nonisolated func nativeExpressBannerAdViewDidClick(_ bannerAdView: BUNativeExpressBannerView) {
        print("👆 用户点击了Banner广告")
    }
    
    // 用户选择了负反馈信息
    nonisolated func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, dislikeWithReason filterwords: [BUDislikeWords]?) {
        Task { @MainActor in
            print("👎 用户选择了负反馈信息")
            // 用户不喜欢该广告，移除广告
            cleanup()
            
            // 延迟重新加载广告，避免立即重复加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                Task { @MainActor in
                    guard let self = self, let viewController = self.rootViewController else { return }
                    print("负反馈后重新加载广告")
                    let containerSize = self.adSize.width > 0 ? self.adSize : self.defaultAdSize
                    self.loadBannerAd(in: viewController, containerSize: containerSize, force: true)
                }
            }
        }
    }
    
    // 广告视图被移除
    nonisolated func nativeExpressBannerAdViewDidRemoved(_ bannerAdView: BUNativeExpressBannerView) {
        Task { @MainActor in
            print("🗑️ Banner广告视图被移除")
            isLoaded = false
            stopAutoRefresh()
        }
    }
}
