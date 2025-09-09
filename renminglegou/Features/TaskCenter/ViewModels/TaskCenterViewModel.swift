//
//  TaskCenterViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation
import Combine
import UIKit

@MainActor
class TaskCenterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccessAlert = false
    @Published var successMessage: String = ""
    
    // MARK: - Sub ViewModels
    let bannerAdViewModel = BannerAdViewModel()
    let taskProgressViewModel = TaskProgressViewModel()
    let dailyVM = DailyTaskViewModel()
    let swipeVM = SwipeTaskViewModel()
    
    // MARK: - Task Config Properties
    @Published var adConfig: AdConfig?
    @Published var rewardConfigs: [AdRewardConfig] = []
    @Published var isSubmittingBrandTask = false
    
    @Published var dailyViewCount: Int = 0
    @Published var dailyTaskProgress: AdTaskProgress?
    @Published var swipeTaskProgress: AdTaskProgress?
    @Published var brandTaskProgress: AdTaskProgress?
    
    // MARK: - Ad Slot Config Properties
    @Published var adPlatformConfig: AdCodeConfig?
    @Published var isLoadingAdSlots = false
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let loadingManager = PureLoadingManager.shared
    
    private let dailyTaskType = 1
    private let swipeTaskType = 2
    private let brandTaskType = 3
    
    // 广告位缓存，按任务类型存储
    private var adSlotCache: [Int: [String]] = [:]
    
    // MARK: - Computed Properties
    
    var dailyTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == dailyTaskType }
    }

    var swipeTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == swipeTaskType }
    }

    var brandTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == brandTaskType }
    }
    
    // 数据加载方法调整
    private func loadAllTaskProgress() async throws {
        let taskTypes = [dailyTaskType, swipeTaskType, brandTaskType]
        try await taskProgressViewModel.loadTaskProgresses(taskTypes: taskTypes)
    }
    
    var canWatchDailyAd: Bool {
        guard let task = dailyTask else { return false }
        let currentCount = dailyTaskProgress?.currentViewCount ?? 0
        return currentCount < task.totalAdCount && !loadingManager.isShowingLoading && !dailyVM.isShowingAd
    }
    
    var isHandlingAd: Bool {
        return loadingManager.isShowingLoading || dailyVM.isShowingAd
    }
    
    // MARK: - Ad Slot Computed Properties
    
    /// 获取当前每日任务应该使用的广告位ID
    var currentDailyAdSlotId: String? {
        return getCurrentAdSlotId(for: dailyTaskType)
    }
    
    /// 获取当前刷刷赚任务应该使用的广告位ID
    var currentSwipeAdSlotId: String? {
        return getCurrentAdSlotId(for: swipeTaskType)
    }
    
    /// 获取当前品牌任务应该使用的广告位ID
    var currentBrandAdSlotId: String? {
        return getCurrentAdSlotId(for: brandTaskType)
    }
    
    // MARK: - Initialization
    init() {
        setupSubViewModels()
        loadData()
    }
    
    // MARK: - Setup Methods
    
    private func setupSubViewModels() {
        // 设置激励广告完成回调
        dailyVM.onAdWatchCompleted = { [weak self] in
            await self?.handleDailyAdWatchCompleted()
        }
        
        // 设置刷视频完成回调
        swipeVM.onAdWatchCompleted = { [weak self] in
            await self?.handleSwipeAdWatchCompleted()
        }
        
        // 初始化各ViewModel的广告位（如果有缓存的话）
        if let dailyAdSlot = currentDailyAdSlotId {
            dailyVM.setAdSlotId(dailyAdSlot)
        }
        
        if let swipeAdSlot = currentSwipeAdSlotId {
            swipeVM.setAdSlotId(swipeAdSlot)
        }
    }
    
    // MARK: - Data Loading Methods
    
    func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            async let adConfigTask: () = loadAdConfig()
            async let rewardConfigsTask: () = loadRewardConfigs()
            async let taskProgressTask: () = loadAllTaskProgress()
            async let adPlatformConfigTask: () = loadAdPlatformConfig()
            
            do {
                _ = try await (adConfigTask, rewardConfigsTask, taskProgressTask, adPlatformConfigTask)
                isLoading = false
                updateTaskProgress()
                
            } catch {
                isLoading = false
                showErrorMessage("数据加载失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadAdConfig() async throws {
        let config = try await taskService.getAdConfig()
        adConfig = config
    }
    
    private func loadRewardConfigs() async throws {
        let configs = try await taskService.getRewardConfigs()
        rewardConfigs = configs
    }
    
    // MARK: - Ad Platform Config Methods
    
    /// 加载广告平台配置
    private func loadAdPlatformConfig() async throws {
        let config = try await taskService.getAdCodeList()
        adPlatformConfig = config
    }
    
    /// 从广告平台配置中获取指定任务类型的广告位
    private func getAdSlotsFromPlatformConfig(for taskType: Int) -> [String]? {
        guard let platformConfig = adPlatformConfig else { return nil }
        
        // 获取当前平台的任务列表
        let currentTasks = platformConfig.currentPlatformTasks
        
        // 查找对应任务类型的广告位
        if let task = currentTasks.first(where: { $0.currentTaskId == taskType }) {
            return task.currentAdSlotIds
        }
        
        return nil
    }
    
    /// 根据已观看数量获取当前应该使用的广告位ID
    private func getCurrentAdSlotId(for taskType: Int) -> String? {
        guard let adSlots = adSlotCache[taskType], !adSlots.isEmpty else {
            return nil
        }
        
        let currentCount = getCurrentViewCount(for: taskType)
        
        // 使用模运算实现循环选择广告位
        let adSlotIndex = currentCount % adSlots.count
        let selectedAdSlot = adSlots[adSlotIndex]
        
        print("📍 任务类型 \(taskType): 已观看 \(currentCount) 次，选择广告位[\(adSlotIndex)]: \(selectedAdSlot)")
        
        return selectedAdSlot
    }
    
    /// 获取指定任务类型的当前观看次数
    private func getCurrentViewCount(for taskType: Int) -> Int {
        switch taskType {
        case dailyTaskType:
            return dailyTaskProgress?.currentViewCount ?? 0
        case swipeTaskType:
            return swipeTaskProgress?.currentViewCount ?? 0
        case brandTaskType:
            return brandTaskProgress?.currentViewCount ?? 0
        default:
            return 0
        }
    }
    
    /// 获取指定任务类型的下一个广告位ID（预加载用）
    func getNextAdSlotId(for taskType: Int) -> String? {
        guard let adSlots = adSlotCache[taskType], !adSlots.isEmpty else {
            return nil
        }
        
        let nextCount = getCurrentViewCount(for: taskType) + 1
        let nextAdSlotIndex = nextCount % adSlots.count
        return adSlots[nextAdSlotIndex]
    }
    
    /// 获取指定任务类型的所有广告位列表
    func getAllAdSlots(for taskType: Int) -> [String] {
        return adSlotCache[taskType] ?? []
    }
    
    // MARK: - Daily Task Methods
    
    func watchDailyTaskAd() {
        // 在观看广告前，确保设置了正确的广告位ID
        if let adSlotId = currentDailyAdSlotId {
            print("🎯 开始观看每日任务广告，广告位ID: \(adSlotId)")
            // 这里可以将广告位ID传递给广告SDK
            dailyVM.setAdSlotId(adSlotId)
        }
        
        dailyVM.watchRewardAd()
    }
    
    private func handleDailyAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            // 刷新进度并领取奖励
            try await taskProgressViewModel.refreshTaskProgress(taskType: dailyTaskType)
            
            updateTaskProgress()
            
            // 3. 预加载下一次的广告位（可选）
            if let nextAdSlotId = getNextAdSlotId(for: dailyTaskType) {
                print("🔄 预加载下一个每日任务广告位: \(nextAdSlotId)")
                // 这里可以预加载下一个广告位
            }
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
        }
    }
    
    private func updateTaskProgress() {
        dailyViewCount = taskProgressViewModel.getCurrentViewCount(for: dailyTaskType)
        dailyTaskProgress = taskProgressViewModel.getProgress(for: dailyTaskType)
        swipeTaskProgress = taskProgressViewModel.getProgress(for: swipeTaskType)
        brandTaskProgress = taskProgressViewModel.getProgress(for: brandTaskType)
    }
    
    // MARK: - Swipe Task Methods
    
    /// 观看刷刷赚广告
    func watchSwipeTaskAd() {
        // 在观看广告前，确保设置了正确的广告位ID
        if let adSlotId = currentSwipeAdSlotId {
            print("🎯 开始观看刷刷赚广告，广告位ID: \(adSlotId)")
            // 设置广告位ID到刷刷赚ViewModel
            swipeVM.setAdSlotId(adSlotId)
            
            // 预加载下一个广告位（提前准备）
            if let nextAdSlotId = getNextAdSlotId(for: swipeTaskType) {
                print("🚀 预加载下一个刷刷赚广告位: \(nextAdSlotId)")
                swipeVM.preloadAd(for: nextAdSlotId)
            }
        } else {
            print("⚠️ 未找到可用的刷刷赚广告位")
            showErrorMessage("暂无可用的广告位，请稍后重试")
            return
        }
        
        swipeVM.watchRewardAd()
    }
    
    /// 刷刷赚广告完成
    private func handleSwipeAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            // 刷新进度并领取奖励
            try await taskProgressViewModel.refreshTaskProgress(taskType: swipeTaskType)
            
            updateTaskProgress()
            
            // 3. 预加载下一次的广告位（可选）
            if let nextAdSlotId = getNextAdSlotId(for: swipeTaskType) {
                print("🔄 预加载下一个刷刷赚广告位: \(nextAdSlotId)")
                // 这里可以预加载下一个广告位
            }
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
        }
    }
    
    // MARK: - Brand Task Methods
    
    func handleBrandTaskResult() {
        
    }
    
    // MARK: - Helper Methods
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccessAlert = true
    }
}

enum TaskTab: CaseIterable {
    case daily
    case swipe
    case brand
    
    var title: String {
        switch self {
        case .daily: return "每日任务"
        case .swipe: return "刷刷赚"
        case .brand: return "品牌任务"
        }
    }
    
    var normalImageName: String {
        switch self {
        case .daily: return "task_center_tab_normal"
        case .swipe: return "task_center_tab_normal"
        case .brand: return "task_center_tab_normal"
        }
    }
    
    var selectedImageName: String {
        switch self {
        case .daily: return "task_center_tab_selected"
        case .swipe: return "task_center_tab_selected"
        case .brand: return "task_center_tab_selected"
        }
    }
}
