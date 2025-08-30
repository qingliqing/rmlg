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
    
    // 广告位配置
    private let defaultSlotID: String
    
    // 广告加载超时定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Initialization
    init(slotID: String = "103510224") {
        self.defaultSlotID = slotID
        setupRewardAdManager()
    }
    
    // MARK: - Private Methods
    private func setupRewardAdManager() {
        rewardAdManager.setEventHandler(for: defaultSlotID) { [weak self] event in
            Task { @MainActor in
                self?.handleRewardAdEvent(event)
            }
        }
        rewardAdManager.preloadAd(for: defaultSlotID)
    }
    
    // MARK: - Public Methods
    
    /// 观看激励广告
    func watchRewardAd() {
        startAdLoading()
        showRewardAd()
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
        
        rewardAdManager.showAd(for: defaultSlotID, from: viewController)
    }
    
    // MARK: - Event Handler (替代原来的 Delegate 方法)
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        switch event {
        case .loadSuccess:
            // 广告加载成功，等待展示
            break
            
        case .loadFailed(let error):
            print("广告加载失败: \(error)")
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            print("广告展示失败: \(error)")
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            // 用户点击了广告
            break
            
        case .closed:
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            isShowingAd = false
            if verified {
                Task {
                    await onAdWatchCompleted?()
                }
            } else {
                print("广告奖励验证失败")
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("广告奖励发放失败: \(String(describing: error))")
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            print("广告播放失败: \(error)")
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
