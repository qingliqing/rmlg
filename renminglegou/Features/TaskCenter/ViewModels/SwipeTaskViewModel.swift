//
//  SwipeVideoViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/29.
//

import Foundation
import Combine
import UIKit

@MainActor
final class SwipeTaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isShowingAd = false
    @Published var adState: AdDisplayState = .idle
    
    // MARK: - Ad Display State
    enum AdDisplayState {
        case idle           // 闲置状态
        case loading        // 加载中
        case ready          // 广告就绪
        case showing        // 正在展示
        case failed         // 失败状态
        
        var description: String {
            switch self {
            case .idle: return "闲置"
            case .loading: return "加载中"
            case .ready: return "就绪"
            case .showing: return "展示中"
            case .failed: return "失败"
            }
        }
    }
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    
    // 广告位配置
    private let defaultSlotID: String
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Initialization
    init(slotID: String = "103510179") {
        self.defaultSlotID = slotID
        setupRewardAdManager()
    }
    
    // MARK: - Private Methods
    private func setupRewardAdManager() {
        // 设置事件处理
        rewardAdManager.setEventHandler(for: defaultSlotID) { [weak self] event in
            Task { @MainActor in
                self?.handleRewardAdEvent(event)
            }
        }
        
        // 预加载广告
        preloadAdIfNeeded()
    }
    
    private func preloadAdIfNeeded() {
        guard !rewardAdManager.isAdReady(for: defaultSlotID) &&
              !rewardAdManager.isAdLoading(for: defaultSlotID) else {
            return
        }
        
        adState = .loading
        rewardAdManager.preloadAd(for: defaultSlotID)
    }
    
    // MARK: - Public Methods
    
    /// 观看激励广告
    func watchRewardAd() {
        print("开始观看广告 - 当前状态: \(rewardAdManager.getStateDescription(for: defaultSlotID))")
        
        // 检查当前广告状态
        if rewardAdManager.isAdReady(for: defaultSlotID) {
            // 广告已准备就绪，直接展示
            showRewardAdDirectly()
        } else if rewardAdManager.isAdLoading(for: defaultSlotID) {
            // 广告正在加载，显示loading等待
            showLoadingAndWaitForAd()
        } else {
            // 广告未加载，开始加载流程
            startAdLoadingProcess()
        }
    }
    
    // MARK: - Private Ad Loading Methods
    
    private func showRewardAdDirectly() {
        adState = .ready
        performAdShow()
    }
    
    private func showLoadingAndWaitForAd() {
        adState = .loading
        loadingManager.showLoading(style: .circle)
        print("广告正在加载中，等待加载完成...")
    }
    
    private func startAdLoadingProcess() {
        adState = .loading
        loadingManager.showLoading(style: .circle)
        
        print("开始加载广告...")
        rewardAdManager.preloadAd(for: defaultSlotID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    print("广告加载完成，准备展示")
                    // 加载成功会通过事件回调处理
                    break
                case .failure(let error):
                    print("广告加载失败: \(error.localizedDescription)")
                    self?.handleAdLoadFailure(error)
                }
            }
        }
    }
    
    private func performAdShow() {
        guard let viewController = getTopViewController() else {
            handleAdShowError("无法获取视图控制器")
            return
        }
        
        print("开始展示广告...")
        rewardAdManager.showAd(
            for: defaultSlotID,
            from: viewController,
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        print("广告开始展示")
                        // 展示成功会通过事件回调处理
                        break
                    case .failure(let error):
                        print("广告展示失败: \(error.localizedDescription)")
                        self?.handleAdShowError("广告展示失败")
                    }
                }
            }
        )
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return nil
        }
        
        return window.rootViewController?.topMostViewController()
    }
    
    private func handleAdLoadFailure(_ error: Error) {
        adState = .failed
        loadingManager.hideLoading()
        loadingManager.showError(message: "广告加载失败，请稍后重试")
    }
    
    private func handleAdShowError(_ message: String) {
        adState = .failed
        loadingManager.hideLoading()
        loadingManager.showError(message: message)
    }
    
    // MARK: - Event Handler
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        print("收到广告事件: \(event.description)")
        
        switch event {
        case .loadStarted:
            print("广告开始加载")
            adState = .loading
            
        case .loadSuccess:
            print("广告加载成功")
            adState = .ready
            // 如果当前正在显示loading，说明用户在等待，现在可以展示广告
            if loadingManager.isShowingLoading {
                performAdShow()
            }
            
        case .loadFailed(let error):
            print("广告加载失败: \(error.localizedDescription)")
            handleAdLoadFailure(error)
            
        case .showStarted:
            print("广告开始展示")
            loadingManager.hideLoading()
            adState = .showing
            
        case .showSuccess:
            print("广告展示成功")
            isShowingAd = true
            adState = .showing
            
        case .showFailed(let error):
            print("广告展示失败: \(error.localizedDescription)")
            handleAdShowError("广告展示失败")
            isShowingAd = false
            
        case .clicked:
            print("用户点击了广告")
            
        case .skipped:
            print("用户跳过了广告")
            
        case .playFinished:
            print("广告播放完成")
            
        case .playFailed(let error):
            print("广告播放失败: \(error.localizedDescription)")
            isShowingAd = false
            adState = .failed
            loadingManager.showError(message: "广告播放失败")
            
        case .rewardSuccess(let verified):
            print("广告奖励成功 - 验证: \(verified)")
            isShowingAd = false
            adState = .idle
            
            if verified {
                Task {
                    await onAdWatchCompleted?()
                }
            } else {
                loadingManager.showError(message: "奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("广告奖励失败: \(error?.localizedDescription ?? "未知错误")")
            isShowingAd = false
            adState = .failed
            loadingManager.showError(message: "奖励发放失败")
            
        case .closed:
            print("广告关闭")
            isShowingAd = false
            adState = .idle
            // 广告关闭后预加载下一个
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.preloadAdIfNeeded()
            }
            
        case .videoDownloaded:
            print("广告视频下载完成")
            adState = .ready
        }
    }
    
    // MARK: - Public State Methods
    
    /// 获取当前广告状态描述（用于调试）
    func getCurrentAdStatus() -> String {
        return """
        ViewModel State: \(adState.description)
        Ad Manager State: \(rewardAdManager.getStateDescription(for: defaultSlotID))
        Is Ready: \(rewardAdManager.isAdReady(for: defaultSlotID))
        Is Loading: \(rewardAdManager.isAdLoading(for: defaultSlotID))
        Is Showing: \(rewardAdManager.isAdShowing(for: defaultSlotID))
        """
    }
    
    /// 强制重新加载广告（调试用）
    func forceReloadAd() {
        print("强制重新加载广告")
        rewardAdManager.destroyManager(for: defaultSlotID)
        adState = .idle
        preloadAdIfNeeded()
    }
    
    // MARK: - Deinitializer
    deinit {
        print("SwipeTaskViewModel 销毁")
    }
}

