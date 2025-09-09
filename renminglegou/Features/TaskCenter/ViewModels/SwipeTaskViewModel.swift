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
    
    // 广告位配置 - 由任务中心动态设置
    private var currentSlotID: String
    private let defaultSlotID = "103510179" // 默认广告位ID作为备选
    
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
            print("⚠️ 刷刷赚广告位ID为空，使用默认广告位: \(defaultSlotID)")
            return
        }
        
        let oldSlotID = currentSlotID
        currentSlotID = slotID
        
        print("🔄 刷刷赚广告位切换: \(oldSlotID) → \(currentSlotID)")
        
        // 为新广告位设置事件处理器并预加载
        setupRewardAdManager()
    }
    
    /// 获取当前广告位ID
    var getCurrentSlotID: String {
        return currentSlotID
    }
    
    /// 预加载指定广告位的广告
    /// - Parameter slotID: 要预加载的广告位ID
    func preloadAd(for slotID: String? = nil) {
        let targetSlotID = slotID ?? currentSlotID
        print("🚀 预加载刷刷赚广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentSlotID)
    }
    
    /// 观看激励广告
    func watchRewardAd() {
        print("🎬 开始观看刷刷赚广告 - 广告位: \(currentSlotID)")
        print("当前状态: \(rewardAdManager.getStateDescription(for: currentSlotID))")
        
        // 检查当前广告状态
        if rewardAdManager.isAdReady(for: currentSlotID) {
            // 广告已准备就绪，直接展示
            showRewardAdDirectly()
            print("✅ 刷刷赚广告已经准备就绪，直接播放")
        } else if rewardAdManager.isAdLoading(for: currentSlotID) {
            // 广告正在加载，显示loading等待
            showLoadingAndWaitForAd()
            print("⏳ 刷刷赚广告正在加载，显示loading")
        } else {
            // 广告未加载，开始加载流程
            startAdLoadingProcess()
            print("🔄 刷刷赚广告未加载，开始加载...")
        }
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
        preloadAdIfNeeded()
    }
    
    private func preloadAdIfNeeded() {
        guard !rewardAdManager.isAdReady(for: currentSlotID) &&
              !rewardAdManager.isAdLoading(for: currentSlotID) else {
            return
        }
        
        adState = .loading
        rewardAdManager.preloadAd(for: currentSlotID)
    }
    
    // MARK: - Private Ad Loading Methods
    
    private func showRewardAdDirectly() {
        adState = .ready
        performAdShow()
    }
    
    private func showLoadingAndWaitForAd() {
        adState = .loading
        loadingManager.showLoading(style: .circle)
        print("⏳ 广告正在加载中，等待加载完成...")
    }
    
    private func startAdLoadingProcess() {
        adState = .loading
        loadingManager.showLoading(style: .circle)
        
        print("🔄 开始加载广告: \(currentSlotID)")
        rewardAdManager.preloadAd(for: currentSlotID) { [weak self] result in
            Task { @MainActor in
                switch result {
                case .success:
                    print("✅ 广告加载完成，准备展示: \(self?.currentSlotID ?? "")")
                    // 加载成功会通过事件回调处理
                    break
                case .failure(let error):
                    print("❌ 广告加载失败: \(error.localizedDescription)")
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
        
        print("🎬 开始展示广告: \(currentSlotID)")
        rewardAdManager.showAd(
            for: currentSlotID,
            from: viewController,
            completion: { [weak self] result in
                Task { @MainActor in
                    switch result {
                    case .success:
                        print("✅ 广告开始展示: \(self?.currentSlotID ?? "")")
                        // 展示成功会通过事件回调处理
                        break
                    case .failure(let error):
                        print("❌ 广告展示失败: \(error.localizedDescription)")
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
        
        // 加载失败时，尝试使用默认广告位
        if currentSlotID != defaultSlotID {
            print("⚠️ 当前广告位加载失败，尝试使用默认广告位")
            setAdSlotId(defaultSlotID)
        }
    }
    
    private func handleAdShowError(_ message: String) {
        adState = .failed
        loadingManager.hideLoading()
        loadingManager.showError(message: message)
    }
    
    // MARK: - Event Handler
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        print("📱 刷刷赚广告事件: \(event.description), 广告位: \(currentSlotID)")
        
        switch event {
        case .loadStarted:
            print("🔄 广告开始加载: \(currentSlotID)")
            adState = .loading
            
        case .loadSuccess:
            print("✅ 广告加载成功: \(currentSlotID)")
            adState = .ready
            // 如果当前正在显示loading，说明用户在等待，现在可以展示广告
            if loadingManager.isShowingLoading {
                performAdShow()
            }
            
        case .loadFailed(let error):
            print("❌ 广告加载失败: \(error.localizedDescription), 广告位: \(currentSlotID)")
            handleAdLoadFailure(error)
            
        case .showStarted:
            print("🎬 广告开始展示: \(currentSlotID)")
            loadingManager.hideLoading()
            adState = .showing
            
        case .showSuccess:
            print("✅ 广告展示成功: \(currentSlotID)")
            isShowingAd = true
            adState = .showing
            
        case .showFailed(let error):
            print("❌ 广告展示失败: \(error.localizedDescription), 广告位: \(currentSlotID)")
            handleAdShowError("广告展示失败")
            isShowingAd = false
            
        case .clicked:
            print("👆 用户点击了广告: \(currentSlotID)")
            
        case .skipped:
            print("⏭️ 用户跳过了广告: \(currentSlotID)")
            
        case .playFinished:
            print("🏁 广告播放完成: \(currentSlotID)")
            
        case .playFailed(let error):
            print("❌ 广告播放失败: \(error.localizedDescription), 广告位: \(currentSlotID)")
            isShowingAd = false
            adState = .failed
            loadingManager.showError(message: "广告播放失败")
            
        case .rewardSuccess(let verified):
            print("🎉 广告奖励成功 - 验证: \(verified), 广告位: \(currentSlotID)")
            isShowingAd = false
            adState = .idle
            
            if verified {
                Task {
                    await onAdWatchCompleted?()
                }
            } else {
                print("⚠️ 奖励验证失败: \(currentSlotID)")
                loadingManager.showError(message: "奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("❌ 广告奖励失败: \(error?.localizedDescription ?? "未知错误"), 广告位: \(currentSlotID)")
            isShowingAd = false
            adState = .failed
            loadingManager.showError(message: "奖励发放失败")
            
        case .closed:
            print("❌ 广告关闭: \(currentSlotID)")
            isShowingAd = false
            adState = .idle
            // 广告关闭后预加载下一个（由任务中心管理，这里不再主动预加载）
            
        case .videoDownloaded:
            print("📥 广告视频下载完成: \(currentSlotID)")
            adState = .ready
        }
    }
    
    // MARK: - Public State Methods
    
    /// 获取当前广告状态描述（用于调试）
    func getCurrentAdStatus() -> String {
        return """
        广告位ID: \(currentSlotID)
        ViewModel State: \(adState.description)
        Ad Manager State: \(rewardAdManager.getStateDescription(for: currentSlotID))
        Is Ready: \(rewardAdManager.isAdReady(for: currentSlotID))
        Is Loading: \(rewardAdManager.isAdLoading(for: currentSlotID))
        Is Showing: \(rewardAdManager.isAdShowing(for: currentSlotID))
        """
    }
    
    /// 强制重新加载广告（调试用）
    func forceReloadAd() {
        print("🔄 强制重新加载广告: \(currentSlotID)")
        rewardAdManager.destroyManager(for: currentSlotID)
        adState = .idle
        preloadAdIfNeeded()
    }
    
    // MARK: - Deinitializer
    deinit {
        print("🗑️ SwipeTaskViewModel 销毁，广告位: \(currentSlotID)")
    }
}
