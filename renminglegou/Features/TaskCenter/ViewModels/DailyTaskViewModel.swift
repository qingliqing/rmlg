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
    @Published var cooldownRemaining: Int = 0  // 冷却剩余时间
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    private let userDefaults = UserDefaults.standard
    
    // 依赖注入
    private weak var adSlotManager: AdSlotManager?
    private weak var taskProgressViewModel: TaskProgressViewModel?
    
    // 广告位配置
    private var currentSlotID: String
    private let defaultSlotID = "103510224" // 默认广告位ID作为备选
    
    // 冷却时间配置
    private var watchIntervalSeconds: Int = 0
    private let lastWatchTimeKey = "last_watch_daily_task"
    
    // 定时器
    private var adLoadingTimer: Timer?
    private var cooldownTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Computed Properties
    
    /// 当前任务进度观看次数
    var currentViewCount: Int {
        return taskProgressViewModel?.getCurrentViewCount(for: AdSlotTaskType.dailyTask.rawValue) ?? 0
    }
    
    /// 当前应该使用的广告位ID
    var currentAdSlotId: String? {
        return adSlotManager?.getCurrentDailyAdSlotId(currentViewCount: currentViewCount)
    }
    
    /// 是否可以观看广告（综合判断）
    var canWatchAd: Bool {
        return cooldownRemaining == 0 &&
               !isShowingAd &&
               (adSlotManager?.hasAvailableAdSlots(for: .dailyTask) ?? false)
    }
    
    /// 按钮显示文案
    var buttonText: String {
        if cooldownRemaining > 0 {
            return "\(cooldownRemaining)秒后可继续"
        } else if !canWatchAd {
            return "暂不可用"
        } else {
            return "看视频"
        }
    }
    
    /// 按钮是否可点击
    var isButtonEnabled: Bool {
        return canWatchAd
    }
    
    // MARK: - Initialization
    init(slotID: String? = nil) {
        self.currentSlotID = slotID ?? defaultSlotID
        setupRewardAdManager()
        startCooldownTimer()
    }
    
    // MARK: - Public Configuration Methods
    
    /// 设置依赖
    func setDependencies(adSlotManager: AdSlotManager, taskProgressViewModel: TaskProgressViewModel) {
        self.adSlotManager = adSlotManager
        self.taskProgressViewModel = taskProgressViewModel
        
        // 从 AdSlotManager 获取观看间隔配置
        self.watchIntervalSeconds = adSlotManager.getWatchInterval(for: .dailyTask)
        updateCooldownTime()
        
        Logger.info("设置 DailyTaskViewModel 依赖，观看间隔: \(watchIntervalSeconds)秒", category: .adSlot)
    }
    
    // MARK: - Public Methods
    
    /// 设置广告位ID（保留，用于手动设置）
    func setAdSlotId(_ slotID: String) {
        guard !slotID.isEmpty else {
            print("广告位ID为空，使用默认广告位: \(defaultSlotID)")
            return
        }
        
        let oldSlotID = currentSlotID
        currentSlotID = slotID
        
        print("广告位切换: \(oldSlotID) -> \(currentSlotID)")
        setupRewardAdManager()
    }
    
    /// 获取当前广告位ID
    var getCurrentSlotID: String {
        return currentSlotID
    }
    
    /// 观看激励广告
    func watchRewardAd() {
        // 检查冷却时间
        guard cooldownRemaining == 0 else {
            loadingManager.showError(message: "请等待 \(cooldownRemaining) 秒后再观看")
            return
        }
        
        // 检查广告位可用性
        guard canWatchAd else {
            loadingManager.showError(message: "暂无可用的广告位或条件不满足")
            return
        }
        
        // 获取当前应该使用的广告位ID
        guard let adSlotId = currentAdSlotId else {
            loadingManager.showError(message: "获取广告位失败，请稍后重试")
            return
        }
        
        // 更新当前使用的广告位ID并设置
        currentSlotID = adSlotId
        setupRewardAdManager()
        
        print("开始观看广告，广告位ID: \(currentSlotID)")
        startAdLoading()
        showRewardAd()
    }
    
    /// 预加载指定广告位的广告
    func preloadAd(for slotID: String? = nil) {
        let targetSlotID = slotID ?? currentSlotID
        print("预加载广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentSlotID)
    }
    
    // MARK: - Private Cooldown Methods
    
    /// 启动冷却时间定时器
    private func startCooldownTimer() {
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCooldownTime()
            }
        }
    }
    
    /// 更新冷却时间
    private func updateCooldownTime() {
        guard let lastWatchTime = userDefaults.object(forKey: lastWatchTimeKey) as? Date else {
            cooldownRemaining = 0
            return
        }
        
        guard watchIntervalSeconds > 0 else {
            cooldownRemaining = 0
            return
        }
        
        let timeSinceLastWatch = Date().timeIntervalSince(lastWatchTime)
        let remainingTime = TimeInterval(watchIntervalSeconds) - timeSinceLastWatch
        
        cooldownRemaining = max(0, Int(remainingTime))
    }
    
    /// 记录观看时间
    private func recordWatchTime() {
        userDefaults.set(Date(), forKey: lastWatchTimeKey)
        userDefaults.synchronize()
        Logger.info("记录每日任务观看时间", category: .adSlot)
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
            print("当前广告位超时，尝试使用默认广告位")
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
    
    // MARK: - Event Handler
    
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        print("广告事件: \(event), 广告位: \(currentSlotID)")
        
        switch event {
        case .loadSuccess:
            print("广告加载成功: \(currentSlotID)")
            
        case .loadFailed(let error):
            print("广告加载失败: \(error), 广告位: \(currentSlotID)")
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            print("广告展示成功: \(currentSlotID)")
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            print("广告展示失败: \(error), 广告位: \(currentSlotID)")
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            print("用户点击广告: \(currentSlotID)")
            
        case .closed:
            print("广告关闭: \(currentSlotID)")
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            print("广告奖励成功: \(verified), 广告位: \(currentSlotID)")
            isShowingAd = false
            if verified {
                // 记录观看时间（开始冷却）
                recordWatchTime()
                updateCooldownTime()
                
                Task {
                    await onAdWatchCompleted?()
                }
            } else {
                print("广告奖励验证失败: \(currentSlotID)")
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("广告奖励发放失败: \(String(describing: error)), 广告位: \(currentSlotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            print("广告播放失败: \(error), 广告位: \(currentSlotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告播放失败")
            
        default:
            break
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        adLoadingTimer?.invalidate()
        cooldownTimer?.invalidate()
        print("DailyTaskViewModel 销毁，广告位: \(currentSlotID)")
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
