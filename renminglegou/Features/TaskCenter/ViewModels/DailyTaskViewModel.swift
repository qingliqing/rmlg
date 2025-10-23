//
//  DailyTaskViewModel.swift
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
    
    // MARK: - Task Progress Properties - 独立管理进度
    @Published var currentViewCount: Int = 0
    @Published var taskProgress: AdTaskProgress?
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    private let userDefaults = UserDefaults.standard
    
    // 依赖注入 - 移除TaskProgressViewModel依赖
    private weak var adSlotManager: AdSlotManager?
    private weak var taskService: TaskCenterService? = TaskCenterService.shared
    
    // 奖励配置
    private var rewardConfigs: [AdRewardConfig] = []
    
    // 广告位配置
    private let defaultSlotID = "103510224" // 默认广告位ID作为备选
    private let taskType = AdSlotTaskType.dailyTask
    
    // 冷却时间配置
    private var watchIntervalSeconds: Int = 0
    private let lastWatchTimeKey = "last_watch_daily_task"
    
    // 定时器
    private var cooldownTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Computed Properties
    
    /// 当前应该使用的广告位ID
    var currentSlotID: String {
        return adSlotManager?.getCurrentDailyAdSlotId(currentViewCount: currentViewCount) ?? defaultSlotID
    }
    
    /// 是否可以观看广告（综合判断）
    var canWatchAd: Bool {
        return cooldownRemaining == 0 &&
               !isShowingAd &&
               (adSlotManager?.hasAvailableAdSlots(for: taskType) ?? false)
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
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentSlotID)
    }
    
    // MARK: - Initialization
    init() {
        preloadAd()
        initializeCooldownState()
    }
    
    // MARK: - Public Configuration Methods
    
    /// 设置依赖 - 移除TaskProgressViewModel
    func setDependencies(adSlotManager: AdSlotManager, taskService: TaskCenterService) {
        self.adSlotManager = adSlotManager
        self.taskService = taskService
        
        // 从 AdSlotManager 获取观看间隔配置
        self.watchIntervalSeconds = adSlotManager.getWatchInterval(for: taskType)
        
        // 立即加载任务进度
        loadTaskProgress()
        
        updateCooldownTime()
        ensureCooldownTimerRunning()
        
        Logger.info("设置 DailyTaskViewModel 依赖，观看间隔: \(watchIntervalSeconds)秒", category: .adSlot)
    }
    
    /// 更新奖励配置
    func updateRewardConfigs(_ configs: [AdRewardConfig]) {
        self.rewardConfigs = configs
    }
    
    // MARK: - Public Methods
    
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
        
        Logger.info("开始观看广告，广告位ID: \(currentSlotID)", category: .adSlot)
        startAdLoading()
        showRewardAd()
    }
    
    /// 获取下一次观看的奖励信息
    func getNextRewardInfo() -> AdRewardConfig? {
        return rewardConfigs.first { config in
            config.adCountStart == (currentViewCount + 1)
        }
    }
    
    // MARK: - Private Task Progress Methods - 独立管理进度
    
    /// 加载任务进度
    private func loadTaskProgress() {
        Task {
            do {
                guard let taskService = taskService else { return }
                let progress = try await taskService.receiveTask(taskType: taskType.rawValue)
                
                await MainActor.run {
                    self.taskProgress = progress
                    self.currentViewCount = progress.currentViewCount
                    Logger.success("每日任务进度加载成功: \(self.currentViewCount)", category: .adSlot)
                }
            } catch {
                Logger.error("加载每日任务进度失败: \(error.localizedDescription)", category: .adSlot)
            }
        }
    }
    
    /// 刷新任务进度
    private func refreshTaskProgress() async throws {
        guard let taskService = taskService else { return }
        
        let progress = try await taskService.receiveTask(taskType: taskType.rawValue)
        self.taskProgress = progress
        self.currentViewCount = progress.currentViewCount
        
        Logger.success("每日任务进度刷新成功: \(self.currentViewCount)", category: .adSlot)
    }
    
    // MARK: - Private Methods - 完整的观看完成处理
    
    /// 完全独立处理观看完成逻辑
    private func handleAdWatchCompleted() async {
        do {
            // 1. 记录观看时间（开始冷却）
            recordWatchTime()
            
            // 2. 刷新任务进度
            try await refreshTaskProgress()
            
            Logger.success("每日任务广告观看完成", category: .adSlot)
            
            // 3.预加载下一个广告
            preloadAd()
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
            Logger.error("处理每日广告完成失败: \(error.localizedDescription)", category: .adSlot)
        }
    }
    
    // MARK: - Private Cooldown Methods
    
    /// 初始化冷却状态
    private func initializeCooldownState() {
        updateCooldownTime()
        ensureCooldownTimerRunning()
    }
    
    /// 启动冷却时间定时器
    private func startCooldownTimer() {
        stopCooldownTimer() // 先停止旧的定时器
        
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCooldownTime()
            }
        }
        Logger.info("启动冷却定时器", category: .adSlot)
    }
    
    /// 停止冷却定时器
    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        Logger.info("停止冷却定时器", category: .adSlot)
    }
    
    /// 确保冷却定时器正在运行（当需要倒计时时）
    private func ensureCooldownTimerRunning() {
        if cooldownRemaining > 0 && (cooldownTimer == nil || !(cooldownTimer?.isValid ?? false)) {
            startCooldownTimer()
        }
    }
    
    /// 更新冷却时间
    private func updateCooldownTime() {
        guard let lastWatchTime = userDefaults.object(forKey: lastWatchTimeKey) as? Date else {
            setCooldownRemaining(0)
            return
        }
        
        guard watchIntervalSeconds > 0 else {
            setCooldownRemaining(0)
            return
        }
        
        let timeSinceLastWatch = Date().timeIntervalSince(lastWatchTime)
        let remainingTime = TimeInterval(watchIntervalSeconds) - timeSinceLastWatch
        let newCooldownRemaining = max(0, Int(remainingTime))
        
        setCooldownRemaining(newCooldownRemaining)
    }
    
    /// 设置冷却剩余时间（避免重复更新和管理定时器）
    private func setCooldownRemaining(_ newValue: Int) {
        // 只在值变化时才更新，避免不必要的UI刷新
        guard cooldownRemaining != newValue else { return }
        
        cooldownRemaining = newValue
        
        // 冷却结束时停止定时器，节省资源
        if cooldownRemaining == 0 {
            stopCooldownTimer()
        }
        
        Logger.debug("冷却时间更新: \(cooldownRemaining)秒", category: .adSlot)
    }
    
    /// 记录观看时间
    private func recordWatchTime() {
        userDefaults.set(Date(), forKey: lastWatchTimeKey)
        userDefaults.synchronize()
        
        // 立即更新一次冷却时间
        updateCooldownTime()
        
        // 确保定时器正在运行（如果冷却时间大于0）
        ensureCooldownTimerRunning()
        
        Logger.info("记录每日任务观看时间，冷却剩余: \(cooldownRemaining)秒", category: .adSlot)
    }
    
    // MARK: - Private Ad Methods
    
    private func preloadAd() {
        // 预加载当前广告位
        rewardAdManager.preloadAd(for: currentSlotID)
    }
    
    private func startAdLoading() {
        loadingManager.showLoading(style: .circle)
    }
    
    private func stopAdLoading() {
        loadingManager.hideLoading()
    }
    
    private func showRewardAd() {
        guard let viewController = UIUtils.findViewController() else {
            stopAdLoading()
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        rewardAdManager.showAd(for: currentSlotID, from: viewController) { event in
            Task { @MainActor in
                self.handleRewardAdEvent(event)
            }
        }
    }
    
    // MARK: - Event Handler
    
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        Logger.info("广告事件: \(event), 广告位: \(currentSlotID)", category: .adSlot)
        
        switch event {
        case .loadSuccess:
            Logger.info("广告加载成功: \(currentSlotID)", category: .adSlot)
            
        case .loadFailed(let error):
            Logger.error("广告加载失败: \(error), 广告位: \(currentSlotID)", category: .adSlot)
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            Logger.info("广告展示成功: \(currentSlotID)", category: .adSlot)
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            Logger.error("广告展示失败: \(error), 广告位: \(currentSlotID)", category: .adSlot)
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            Logger.info("用户点击广告: \(currentSlotID)", category: .adSlot)
            
        case .closed:
            Logger.info("广告关闭: \(currentSlotID)", category: .adSlot)
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            Logger.info("广告奖励成功: \(verified), 广告位: \(currentSlotID)", category: .adSlot)
            isShowingAd = false
            if verified {
                Task {
                    await handleAdWatchCompleted()
                }
            } else {
                Logger.warning("广告奖励验证失败: \(currentSlotID)", category: .adSlot)
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            Logger.error("广告奖励发放失败: \(String(describing: error)), 广告位: \(currentSlotID)", category: .adSlot)
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            Logger.error("广告播放失败: \(error), 广告位: \(currentSlotID)", category: .adSlot)
            isShowingAd = false
            loadingManager.showError(message: "广告播放失败")
            
        default:
            break
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        cooldownTimer?.invalidate()
        Logger.info("DailyTaskViewModel 销毁", category: .adSlot)
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
