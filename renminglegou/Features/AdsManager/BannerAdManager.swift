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
import SwiftUI
import UIKit
// 假设你导入的是穿山甲SDK
// import BUAdSDK

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
    
    /// 加载Banner广告
    @MainActor
    func loadBannerAd(in viewController: UIViewController, containerSize: CGSize) {
        rootViewController = viewController
        
        // 清理上次的广告
        cleanup()
        
        // 根据容器尺寸调整广告尺寸
        let adaptedSize = adaptAdSize(to: containerSize)
        adSize = adaptedSize
        
        isLoading = true
        errorMessage = nil
        
        // 创建广告位配置
        let slot = BUAdSlot()
        slot.id = slotId
        
        // 创建Banner广告视图
        let bannerView = BUNativeExpressBannerView(
            slot: slot,
            rootViewController: viewController,
            adSize: adaptedSize
        )
        bannerView.delegate = self
        
        self.bannerView = bannerView
        bannerView.loadAdData()
        
        print("开始加载Banner广告，尺寸: \(adaptedSize)")
    }
    
    /// 获取当前的Banner视图
    func getBannerView() -> UIView? {
        return bannerView
    }
    
    /// 开始自动刷新
    @MainActor
    func startAutoRefresh() async {
        stopAutoRefresh()
        
        guard refreshInterval > 0 else { return }
        
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.refreshAd()
            }
        }
        
        print("开始自动刷新Banner广告，间隔: \(refreshInterval)秒")
    }
    
    /// 停止自动刷新
    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    /// 手动刷新广告
    @MainActor
    func refreshAd() async {
        guard let viewController = rootViewController else { return }
        
        let containerSize = CGSize(width: adSize.width, height: adSize.height)
        loadBannerAd(in: viewController, containerSize: containerSize)
        
        print("手动刷新Banner广告")
    }
    
    /// 清理资源
    @MainActor
    func cleanup() {
        bannerView?.removeFromSuperview()
        bannerView = nil
        isLoaded = false
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
            print("Banner广告加载成功")
            isLoading = false
            isLoaded = true
            errorMessage = nil
            
            // 更新实际广告尺寸
            adSize = bannerAdView.frame.size
        }
    }
    
    // 广告加载失败
    nonisolated func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, didLoadFailWithError error: Error?) {
        Task { @MainActor in
            print("Banner广告加载失败: \(error?.localizedDescription ?? "Unknown error")")
            isLoading = false
            isLoaded = false
            errorMessage = error?.localizedDescription ?? "广告加载失败"
        }
    }
    
    // 广告已经展示
    nonisolated func nativeExpressBannerAdViewWillBecomVisible(_ bannerAdView: BUNativeExpressBannerView) {
        Task { @MainActor in
            print("Banner广告已经展示")
            // 广告展示成功后开始自动刷新
            await startAutoRefresh()
            
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
        print("用户点击了Banner广告")
    }
    
    // 用户选择了负反馈信息
    nonisolated func nativeExpressBannerAdView(_ bannerAdView: BUNativeExpressBannerView, dislikeWithReason filterwords: [BUDislikeWords]?) {
        Task { @MainActor in
            print("用户选择了负反馈信息")
            // 用户不喜欢该广告，移除广告并可能重新加载
            cleanup()
            
            // 延迟重新加载广告
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                Task { @MainActor in
                    if let viewController = self?.rootViewController {
                        let containerSize = self?.adSize ?? self?.defaultAdSize ?? CGSize(width: 375, height: 160)
                        self?.loadBannerAd(in: viewController, containerSize: containerSize)
                    }
                }
            }
        }
    }
    
    // 广告视图被移除
    nonisolated func nativeExpressBannerAdViewDidRemoved(_ bannerAdView: BUNativeExpressBannerView) {
        Task { @MainActor in
            print("Banner广告视图被移除")
            isLoaded = false
            stopAutoRefresh()
        }
    }
}


