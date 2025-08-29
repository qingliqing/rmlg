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
final class RewardAdViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isShowingAd = false
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    
    // 广告加载超时定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Initialization
    init() {
        setupRewardAdManager()
    }
    
    // MARK: - Private Methods
    private func setupRewardAdManager() {
        rewardAdManager.delegate = self
        rewardAdManager.preloadAd()
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
              let viewController = window.rootViewController else {
            stopAdLoading()
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        rewardAdManager.showAd(from: viewController)
    }
    
    // MARK: - Deinitializer
    deinit {
        adLoadingTimer?.invalidate()
    }
}

// MARK: - RewardAdManagerDelegate
extension RewardAdViewModel: RewardAdManagerDelegate {
    
    nonisolated func rewardAdDidLoad() {
        // 广告加载成功，等待展示
    }
    
    nonisolated func rewardAdDidFailToLoad(error: Error?) {
        Task { @MainActor in
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
        }
    }
    
    nonisolated func rewardAdDidShow() {
        Task { @MainActor in
            stopAdLoading()
            isShowingAd = true
        }
    }
    
    nonisolated func rewardAdDidFailToShow(error: Error) {
        Task { @MainActor in
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
        }
    }
    
    nonisolated func rewardAdDidClick() {
        // 用户点击了广告
    }
    
    nonisolated func rewardAdDidClose() {
        Task { @MainActor in
            isShowingAd = false
        }
    }
    
    nonisolated func rewardAdDidRewardUser(verified: Bool) {
        Task { @MainActor in
            isShowingAd = false
            if verified {
                await onAdWatchCompleted?()
            } else {
                loadingManager.showError(message: "广告奖励验证失败")
            }
        }
    }
    
    nonisolated func rewardAdDidFailToReward(error: Error?) {
        Task { @MainActor in
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
        }
    }
    
    nonisolated func rewardAdDidFinishPlaying(error: Error?) {
        Task { @MainActor in
            isShowingAd = false
            if error != nil {
                loadingManager.showError(message: "广告播放失败")
            }
        }
    }
}
