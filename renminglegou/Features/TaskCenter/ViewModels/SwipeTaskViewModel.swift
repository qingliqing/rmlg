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
    
    // 依赖注入
    private weak var adSlotManager: AdSlotManager?
    private weak var taskProgressViewModel: TaskProgressViewModel?
    
    // 广告位配置
    private var currentSlotID: String
    private let defaultSlotID = "103510179" // 默认广告位ID作为备选
    
    // 任务配置
    private var swipeTask: AdTask?
    
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
    var currentAdSlotId: String? {
        return adSlotManager?.getCurrentSwipeAdSlotId(currentViewCount: currentViewCount)
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
    init(slotID: String? = nil) {
        self.currentSlotID = slotID ?? defaultSlotID
        setupRewardAdManager()
        setupAdCallbacks()
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
        updateTaskState()
        
        Logger.info("设置 SwipeTaskViewModel 依赖", category: .adSlot)
    }
    
    // MARK: - Public Business Methods
    
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
        
        // 获取当前应该使用的广告位
        guard let adSlotId = currentAdSlotId else {
            loadingManager.showError(message: "获取广告位失败，请稍后重试")
            return
        }
        
        // 更新当前使用的广告位ID并开始观看广告
        currentSlotID = adSlotId
        setupRewardAdManager()
        
        print("开始刷视频任务，广告位ID: \(currentSlotID)")
        watchRewardAd()
    }
    
    /// 设置广告位ID
    func setAdSlotId(_ slotID: String) {
        guard !slotID.isEmpty else {
            print("刷刷赚广告位ID为空，使用默认广告位: \(defaultSlotID)")
            return
        }
        
        let oldSlotID = currentSlotID
        currentSlotID = slotID
        
        print("刷刷赚广告位切换: \(oldSlotID) -> \(currentSlotID)")
        setupRewardAdManager()
    }
    
    /// 获取当前广告位ID
    var getCurrentSlotID: String {
        return currentSlotID
    }
    
    /// 预加载指定广告位的广告
    func preloadAd(for slotID: String? = nil) {
        let targetSlotID = slotID ?? currentSlotID
        print("预加载刷刷赚广告位: \(targetSlotID)")
        rewardAdManager.preloadAd(for: targetSlotID)
    }
    
    /// 检查当前广告位是否已加载
    var isAdReady: Bool {
        return rewardAdManager.isAdReady(for: currentSlotID)
    }
    
    // MARK: - Private Business Methods
    
    /// 设置广告完成回调
    private func setupAdCallbacks() {
        onAdWatchCompleted = { [weak self] in
            await self?.handleAdWatchCompleted()
        }
    }
    
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
        // 更新进度
        await onAdWatchCompleted?()
        updateTaskState()
        
        // 预加载下一个广告位的广告
        if !isTaskCompleted, let nextAdSlotId = currentAdSlotId {
            preloadAd(for: nextAdSlotId)
        }
        
        Logger.info("刷视频任务完成一次，当前进度: \(currentProgress)", category: .adSlot)
    }
    
    // MARK: - Private Ad Methods
    
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
    
    func watchRewardAd() {
        guard let viewController = UIUtils.findViewController() else {
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        startAdLoading()
        rewardAdManager.showAd(for: currentSlotID, from: viewController)
    }
    
    // MARK: - Event Handler
    
    private func handleRewardAdEvent(_ event: RewardAdEvent) {
        print("刷刷赚广告事件: \(event), 广告位: \(currentSlotID)")
        
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
        print("SwipeTaskViewModel 销毁，广告位: \(currentSlotID)")
    }
}
