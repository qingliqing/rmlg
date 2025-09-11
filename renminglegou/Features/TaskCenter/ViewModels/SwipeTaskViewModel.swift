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
    @Published var currentProgress = 0
    @Published var canStartTask = true
    
    // MARK: - Private Properties
    private let rewardAdManager = RewardAdManager.shared
    private let loadingManager = PureLoadingManager.shared
    private let userDefaults = UserDefaults.standard
    
    // 依赖注入
    private weak var adSlotManager: AdSlotManager?
    private weak var taskProgressViewModel: TaskProgressViewModel?
    
    // 广告位配置
    private let defaultSlotID = "103510179" // 默认广告位ID作为备选
    
    // 任务配置
    private var swipeTask: AdTask?
    
    // 冷却时间配置
    private var watchIntervalSeconds: Int = 0
    private let lastWatchTimeKey = "last_watch_swipe_task"
    
    // 定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Callbacks
    var onAdWatchCompleted: (() async -> Void)?
    
    // MARK: - Computed Properties
    
    /// 当前任务进度观看次数
    var currentViewCount: Int {
        return taskProgressViewModel?.getCurrentViewCount(for: AdTaskType.swipeTask.rawValue) ?? 0
    }
    
    /// 当前应该使用的广告位ID
    var currentAdSlotId: String {
        return adSlotManager?.getCurrentSwipeAdSlotId(currentViewCount: currentViewCount) ?? defaultSlotID
    }
    
    /// 是否可以观看广告（综合判断）
    var canWatchAd: Bool {
        return !isShowingAd &&
               !isTaskCompleted &&
                (adSlotManager?.hasAvailableAdSlots(for: .swipeTask) ?? false)
    }
    
    /// 按钮是否可点击
    var isButtonEnabled: Bool {
        return canStartTask && !isTaskCompleted
    }
    
    // MARK: - Initialization
    init() {
        // 简化初始化，不需要预设广告位
    }
    
    // MARK: - Public Configuration Methods
    
    /// 设置依赖
    func setDependencies(
        adSlotManager: AdSlotManager,
        taskProgressViewModel: TaskProgressViewModel,
        swipeTask: AdTask?
    ) {
        self.adSlotManager = adSlotManager
        self.taskProgressViewModel = taskProgressViewModel
        self.swipeTask = swipeTask
        
        // 从 AdSlotManager 获取观看间隔配置
        self.watchIntervalSeconds = adSlotManager.getWatchInterval(for: .swipeTask)
        updateTaskState()
        
        Logger.info("设置 SwipeTaskViewModel 依赖，观看间隔: \(watchIntervalSeconds)秒", category: .adSlot)
    }
    
    // MARK: - Public Business Methods
    
    func checkRemainColddown() -> Bool {
        // 检查冷却时间
        let remainingCooldown = getRemainingCooldownTime()
        guard remainingCooldown == 0 else {
            loadingManager.showAlert(message: "请等待\(remainingCooldown)秒后再观看",position: .center)
            return false
        }
        return true
    }
    
    /// 开始刷视频任务
    func startSwipeTask(rewardConfig: AdRewardConfig?) {
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
    
    /// 预加载指定广告位的广告
    func preloadAd() {
        let targetSlotID = currentAdSlotId
        print("预加载刷刷赚广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentAdSlotId)
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
        guard let swipeTask = swipeTask else { return }
        
        currentProgress = currentViewCount
        isTaskCompleted = currentProgress >= swipeTask.totalAdCount
        canStartTask = !isTaskCompleted
        
        Logger.debug("刷视频任务状态更新 - 进度: \(currentProgress)/\(swipeTask.totalAdCount), 已完成: \(isTaskCompleted)", category: .adSlot)
    }
    
    /// 处理广告观看完成
    private func handleAdWatchCompleted() async {
        // 记录观看时间（开始冷却）
        recordWatchTime()
        
        // 更新进度
        await onAdWatchCompleted?()
        updateTaskState()
        
        // 预加载下一个广告位的广告
        if !isTaskCompleted {
            preloadAd()
        }
        
        Logger.info("刷视频任务完成一次，当前进度: \(currentProgress)", category: .adSlot)
    }
    
    // MARK: - Private Ad Methods
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
        rewardAdManager.setEventHandler(for: slotID) { [weak self] event in
            Task { @MainActor in
                self?.handleRewardAdEvent(event, for: slotID)
            }
        }
        rewardAdManager.showAd(for: slotID, from: viewController)
    }
    
    // MARK: - Event Handler
    
    private func handleRewardAdEvent(_ event: RewardAdEvent, for slotID: String) {
        print("刷刷赚广告事件: \(event), 广告位: \(slotID)")
        
        switch event {
        case .loadSuccess:
            print("广告加载成功: \(slotID)")
            
        case .loadFailed(let error):
            print("广告加载失败: \(error), 广告位: \(slotID)")
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
            
        case .showSuccess:
            print("广告展示成功: \(slotID)")
            stopAdLoading()
            isShowingAd = true
            
        case .showFailed(let error):
            print("广告展示失败: \(error), 广告位: \(slotID)")
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
            
        case .clicked:
            print("用户点击广告: \(slotID)")
            
        case .closed:
            print("广告关闭: \(slotID)")
            isShowingAd = false
            
        case .rewardSuccess(let verified):
            print("广告奖励成功: \(verified), 广告位: \(slotID)")
            isShowingAd = false
            if verified {
                Task {
                    await handleAdWatchCompleted()
                }
            } else {
                print("广告奖励验证失败: \(slotID)")
                loadingManager.showError(message: "广告奖励验证失败")
            }
            
        case .rewardFailed(let error):
            print("广告奖励发放失败: \(String(describing: error)), 广告位: \(slotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
            
        case .playFailed(let error):
            print("广告播放失败: \(error), 广告位: \(slotID)")
            isShowingAd = false
            loadingManager.showError(message: "广告播放失败")
            
        default:
            break
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        adLoadingTimer?.invalidate()
        print("SwipeTaskViewModel 销毁")
    }
}
