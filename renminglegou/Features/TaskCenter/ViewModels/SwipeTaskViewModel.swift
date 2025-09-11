//
//  SwipeTaskViewModel.swift
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
    @Published var isTaskCompleted = false
    @Published var canStartTask = true
    
    // MARK: - Task Progress Properties - 独立管理进度
    @Published var currentViewCount: Int = 0
    @Published var currentProgress: Int = 0
    @Published var taskProgress: AdTaskProgress?
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    private let userDefaults = UserDefaults.standard
    
    // 依赖注入 - 移除TaskProgressViewModel依赖
    private var adSlotManager: AdSlotManager = AdSlotManager.shared
    private var taskService: TaskCenterService = TaskCenterService.shared
    
    // 任务配置
    private var task: AdTask?
    private var rewardConfigs: [AdRewardConfig] = []
    
    // 广告位配置
    private let defaultSlotID = "103510179" // 默认广告位ID作为备选
    private let taskType = AdTaskType.swipeTask
    
    // 冷却时间配置
    private var watchIntervalSeconds: Int = 0
    private let lastWatchTimeKey = "last_watch_swipe_task"
    
    // 定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Computed Properties
    /// 当前应该使用的广告位ID
    var currentAdSlotId: String {
        return adSlotManager.getCurrentSwipeAdSlotId(currentViewCount: currentViewCount) ?? defaultSlotID
    }
    
    /// 是否可以观看广告（综合判断）
    var canWatchAd: Bool {
        return !isShowingAd &&
               !isTaskCompleted &&
                (adSlotManager.hasAvailableAdSlots(for: AdSlotTaskType.swipeTask))
    }
    
    /// 按钮是否可点击
    var isButtonEnabled: Bool {
        return canStartTask && !isTaskCompleted
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentAdSlotId)
    }
    
    // MARK: - Initialization
    init() {
        // 从 AdSlotManager 获取观看间隔配置
        self.watchIntervalSeconds = adSlotManager.getWatchInterval(for: AdSlotTaskType.swipeTask)
        
        // 立即加载任务进度（进度加载成功后会自动预加载广告）
        loadTaskProgress()
    }
    
    // MARK: - Public Configuration Methods
    
    /// 更新任务配置
    func updateTask(_ task: AdTask?) {
        self.task = task
        updateTaskState()
    }
    
    /// 更新奖励配置
    func updateRewardConfigs(_ configs: [AdRewardConfig]) {
        self.rewardConfigs = configs
    }
    
    // MARK: - Public Business Methods
    
    func checkRemainColddown() -> Bool {
        // 检查冷却时间
        let remainingCooldown = getRemainingCooldownTime()
        guard remainingCooldown == 0 else {
            loadingManager.showAlert(message: "请等待\(remainingCooldown)秒后再观看", position: .center)
            return false
        }
        return true
    }
    
    /// 开始刷视频任务
    func startSwipeTask() {
        guard canStartTask else {
            loadingManager.showError(message: "当前无法开始任务")
            return
        }
        
        guard !isTaskCompleted else {
            loadingManager.showError(message: "今日任务已完成")
            return
        }
        
        let adSlotId = currentAdSlotId
        Logger.info("开始刷刷赚任务，广告位ID: \(adSlotId)", category: .adSlot)
        watchRewardAd(with: adSlotId)
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
                let progress = try await taskService.receiveTask(taskType: taskType.rawValue)
                
                await MainActor.run {
                    self.taskProgress = progress
                    self.currentViewCount = progress.currentViewCount
                    self.updateTaskState()
                    Logger.success("刷刷赚任务进度加载成功: \(self.currentViewCount)", category: .adSlot)
                    self.preloadAd()
                }
            } catch {
                Logger.error("加载刷刷赚任务进度失败: \(error.localizedDescription)", category: .adSlot)
            }
        }
    }
    
    // MARK: - Private Methods - 完整的观看完成处理
    
    /// 完全独立处理观看完成逻辑
    private func handleAdWatchCompleted() async {
        
        // 1. 记录观看时间（开始冷却）
        recordWatchTime()
        
        // 2. 刷新任务进度
        loadTaskProgress()
        
        Logger.success("刷刷赚广告观看完成", category: .adSlot)
    }
    
    // MARK: - Private Cooldown Methods
    
    /// 获取剩余冷却时间（秒）
    private func getRemainingCooldownTime() -> Int {
        guard let lastWatchTime = userDefaults.object(forKey: lastWatchTimeKey) as? Date else {
            return 0
        }
        
        guard watchIntervalSeconds > 0 else {
            return 0
        }
        
        let timeSinceLastWatch = Date().timeIntervalSince(lastWatchTime)
        let remainingTime = TimeInterval(watchIntervalSeconds) - timeSinceLastWatch
        
        return max(0, Int(remainingTime))
    }
    
    /// 记录观看时间
    private func recordWatchTime() {
        userDefaults.set(Date(), forKey: lastWatchTimeKey)
        userDefaults.synchronize()
        
        Logger.info("记录刷刷赚任务观看时间", category: .adSlot)
    }
    
    // MARK: - Private Business Methods
    
    /// 更新任务状态
    private func updateTaskState() {
        guard let task = task else { return }
        
        currentProgress = currentViewCount
        isTaskCompleted = currentProgress >= task.totalAdCount
        canStartTask = !isTaskCompleted
        
        Logger.debug("刷视频任务状态更新 - 进度: \(currentProgress)/\(task.totalAdCount), 已完成: \(isTaskCompleted)", category: .adSlot)
    }
    
    // MARK: - Private Ad Methods
    
    private func preloadAd() {
        let targetSlotID = currentAdSlotId
        print("预加载刷刷赚广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
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
    }
    
    private func watchRewardAd(with slotID: String) {
        guard let viewController = UIUtils.findViewController() else {
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        startAdLoading()
        rewardAdManager.showAd(for: slotID, from: viewController) {[weak self] event in
            Task { @MainActor in
                self?.handleRewardAdEvent(event, for: slotID)
            }
        }
    }
    
    // MARK: - Event Handler
    
    private func handleRewardAdEvent(_ event: RewardAdEvent, for slotID: String) {
        Logger.info("刷刷赚广告事件: \(event), 广告位: \(slotID)", category: .adSlot)
        
        switch event {
        case .loadSuccess:
            Logger.info("广告加载成功: \(slotID)", category: .adSlot)
            
        case .loadFailed(let error):
            Logger.error("广告加载失败: \(error), 广告位: \(slotID)", category: .adSlot)
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            Logger.info("广告展示成功: \(slotID)", category: .adSlot)
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            Logger.error("广告展示失败: \(error), 广告位: \(slotID)", category: .adSlot)
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            Logger.info("用户点击广告: \(slotID)", category: .adSlot)
            
        case .closed:
            Logger.info("广告关闭: \(slotID)", category: .adSlot)
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            Logger.info("广告奖励成功: \(verified), 广告位: \(slotID)", category: .adSlot)
            isShowingAd = false
            if verified {
                Task {
                    await handleAdWatchCompleted()
                }
            } else {
                Logger.warning("广告奖励验证失败: \(slotID)", category: .adSlot)
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            Logger.error("广告奖励发放失败: \(String(describing: error)), 广告位: \(slotID)", category: .adSlot)
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            Logger.error("广告播放失败: \(error), 广告位: \(slotID)", category: .adSlot)
            isShowingAd = false
            loadingManager.showError(message: "广告播放失败")
            
        default:
            break
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        adLoadingTimer?.invalidate()
        Logger.info("SwipeTaskViewModel 销毁", category: .adSlot)
    }
}
