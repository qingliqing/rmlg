//
//  RewardAdViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/29.
//

import Foundation
import UIKit
import Combine

@MainActor
final class DailyTaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isShowingAd = false
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    
    // 广告位配置 - 由任务中心动态设置
    private var currentSlotID: String
    private let defaultSlotID = "103510224" // 默认广告位ID作为备选
    
    // 广告加载超时定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Initialization
    init(slotID: String? = nil) {
        self.currentSlotID = slotID ?? defaultSlotID
        setupRewardAdManager()
    }
    
    // MARK: - Public Methods
    
    /// 设置广告位ID - 由任务中心调用
    /// - Parameter slotID: 新的广告位ID
    func setAdSlotId(_ slotID: String) {
        guard !slotID.isEmpty else {
            print("⚠️ 广告位ID为空，使用默认广告位: \(defaultSlotID)")
            return
        }
        
        let oldSlotID = currentSlotID
        currentSlotID = slotID
        
        print("🔄 广告位切换: \(oldSlotID) → \(currentSlotID)")
        
        // 为新广告位设置事件处理器并预加载
        setupRewardAdManager()
    }
    
    /// 获取当前广告位ID
    var getCurrentSlotID: String {
        return currentSlotID
    }
    
    /// 观看激励广告
    func watchRewardAd() {
        print("🎬 开始观看广告，广告位ID: \(currentSlotID)")
        startAdLoading()
        showRewardAd()
    }
    
    /// 预加载指定广告位的广告
    /// - Parameter slotID: 要预加载的广告位ID
    func preloadAd(for slotID: String? = nil) {
        let targetSlotID = slotID ?? currentSlotID
        print("🚀 预加载广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentSlotID)
    }
    
    // MARK: - Private Methods
    private func setupRewardAdManager() {
        // 为当前广告位设置事件处理器
        rewardAdManager.setEventHandler(for: currentSlotID) { [weak self] event in
            Task { @MainActor in
                self?.handleRewardAdEvent(event)
            }
        }
        
        // 预加载当前广告位
        rewardAdManager.preloadAd(for: currentSlotID)
    }
    
    // MARK: - Private Ad Loading Methods
    private func startAdLoading() {
        loadingManager.showLoading(style: .circle)
        
        adLoadingTimer = Timer.scheduledTimer(withTimeInterval: adLoadingTimeoutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleAdLoadingTimeout()
            }
        }
    }
    
    private func stopAdLoading() {
        loadingManager.hideLoading()
        adLoadingTimer?.invalidate()
        adLoadingTimer = nil
    }
    
    private func handleAdLoadingTimeout() {
        stopAdLoading()
        loadingManager.showError(message: "广告加载超时，请稍后重试")
        
        // 广告加载超时时，尝试使用默认广告位
        if currentSlotID != defaultSlotID {
            print("⚠️ 当前广告位超时，尝试使用默认广告位")
            setAdSlotId(defaultSlotID)
        }
    }
    
    private func showRewardAd() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow),
              let viewController = window.rootViewController?.topMostViewController() else {
            stopAdLoading()
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        rewardAdManager.showAd(for: currentSlotID, from: viewController)
    }
    
    // MARK: - Event Handler (替代原来的 Delegate 方法)
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        print("📱 广告事件: \(event), 广告位: \(currentSlotID)")
        
        switch event {
        case .loadSuccess:
            // 广告加载成功，等待展示
            print("✅ 广告加载成功: \(currentSlotID)")
            
        case .loadFailed(let error):
            print("❌ 广告加载失败: \(error), 广告位: \(currentSlotID)")
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            print("🎬 广告展示成功: \(currentSlotID)")
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            print("❌ 广告展示失败: \(error), 广告位: \(currentSlotID)")
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            print("👆 用户点击广告: \(currentSlotID)")
            
        case .closed:
            print("❌ 广告关闭: \(currentSlotID)")
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            print("🎉 广告奖励成功: \(verified), 广告位: \(currentSlotID)")
            isShowingAd = false
            if verified {
                Task {
                    await onAdWatchCompleted?()
                }
            } else {
                print("⚠️ 广告奖励验证失败: \(currentSlotID)")
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("❌ 广告奖励发放失败: \(String(describing: error)), 广告位: \(currentSlotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            print("❌ 广告播放失败: \(error), 广告位: \(currentSlotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告播放失败")
            
        default:
            // 其他事件暂不处理
            break
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        adLoadingTimer?.invalidate()
        print("🗑️ DailyTaskViewModel 销毁，广告位: \(currentSlotID)")
    }
}

// MARK: - UIViewController Extension (Helper)
extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.topMostViewController() ?? navigationController
        }
        
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.topMostViewController() ?? tabBarController
        }
        
        return self
    }
}
