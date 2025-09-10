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
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let loadingManager = PureLoadingManager.shared
    private let adSlotManager = AdSlotManager.shared
    
    // 使用枚举替代硬编码常量
    private let dailyTaskType = AdSlotTaskType.dailyTask
    private let swipeTaskType = AdSlotTaskType.browsing
    private let brandTaskType = AdSlotTaskType.splash
    
    // MARK: - Computed Properties
    
    var dailyTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == dailyTaskType.rawValue }
    }

    var swipeTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == swipeTaskType.rawValue }
    }

    var brandTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == brandTaskType.rawValue }
    }
    
    var isHandlingAd: Bool {
        return loadingManager.isShowingLoading || dailyVM.isShowingAd
    }
    
    // MARK: - Initialization
    init() {
        setupSubViewModels()
        loadData()
    }
    
    // MARK: - Setup Methods
    
    private func setupSubViewModels() {
        // 设置子ViewModel的依赖
        dailyVM.setDependencies(
            adSlotManager: adSlotManager,
            taskProgressViewModel: taskProgressViewModel
        )
        
        // 设置完成回调
        dailyVM.onAdWatchCompleted = { [weak self] in
            await self?.handleDailyAdWatchCompleted()
        }
        
        swipeVM.onAdWatchCompleted = { [weak self] in
            await self?.handleSwipeAdWatchCompleted()
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
            
            do {
                _ = try await (adConfigTask, rewardConfigsTask, taskProgressTask)
                isLoading = false
                updateTaskProgress()
                
            } catch {
                isLoading = false
                showErrorMessage("数据加载失败: \(error.localizedDescription)")
                Logger.error("TaskCenter数据加载失败: \(error.localizedDescription)", category: .general)
            }
        }
    }
    
    private func loadAdConfig() async throws {
        let config = try await taskService.getAdConfig()
        adConfig = config
        Logger.success("广告配置加载成功", category: .general)
    }
    
    private func loadRewardConfigs() async throws {
        let configs = try await taskService.getRewardConfigs()
        rewardConfigs = configs
        Logger.success("奖励配置加载成功", category: .general)
    }
    
    private func loadAllTaskProgress() async throws {
        let taskTypes = [dailyTaskType.rawValue, swipeTaskType.rawValue, brandTaskType.rawValue]
        try await taskProgressViewModel.loadTaskProgresses(taskTypes: taskTypes)
        Logger.success("任务进度加载成功", category: .general)
    }
    
    private func updateTaskProgress() {
        dailyViewCount = taskProgressViewModel.getCurrentViewCount(for: dailyTaskType.rawValue)
        dailyTaskProgress = taskProgressViewModel.getProgress(for: dailyTaskType.rawValue)
        swipeTaskProgress = taskProgressViewModel.getProgress(for: swipeTaskType.rawValue)
        brandTaskProgress = taskProgressViewModel.getProgress(for: brandTaskType.rawValue)
        
        Logger.debug("任务进度更新 - 每日:\(dailyViewCount), 刷刷赚:\(swipeTaskProgress?.currentViewCount ?? 0)", category: .general)
    }
    
    // MARK: - Daily Task Methods (简化为直接调用)
    
    func watchDailyTaskAd() {
        // 直接调用子ViewModel的方法，让它自己处理所有逻辑
        dailyVM.watchRewardAd()
    }
    
    private func handleDailyAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            // 刷新进度
            try await taskProgressViewModel.refreshTaskProgress(taskType: dailyTaskType.rawValue)
            updateTaskProgress()
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            Logger.success("每日任务广告观看完成", category: .adSlot)
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
            Logger.error("处理每日广告完成失败: \(error.localizedDescription)", category: .adSlot)
        }
    }
    
    // MARK: - Swipe Task Methods (保持原有逻辑)
    
    func watchSwipeTaskAd() {
        guard adSlotManager.isInitialized else {
            showErrorMessage("广告位尚未初始化，请稍后重试")
            Logger.warning("广告位管理器未初始化，无法观看刷刷赚广告", category: .adSlot)
            return
        }
        
        let currentCount = swipeTaskProgress?.currentViewCount ?? 0
        guard let adSlotId = adSlotManager.getCurrentSwipeAdSlotId(currentViewCount: currentCount) else {
            showErrorMessage("暂无可用的广告位，请稍后重试")
            Logger.warning("未找到可用的刷刷赚广告位", category: .adSlot)
            return
        }
        
        Logger.adSlot("开始观看刷刷赚广告，广告位ID: \(adSlotId)")
        swipeVM.setAdSlotId(adSlotId)
        
        // 预加载下一个广告位
        if let nextAdSlotId = adSlotManager.getNextSwipeAdSlotId(currentViewCount: currentCount) {
            Logger.info("预加载下一个刷刷赚广告位: \(nextAdSlotId)", category: .adSlot)
            swipeVM.preloadAd(for: nextAdSlotId)
        }
        
        swipeVM.watchRewardAd()
    }
    
    private func handleSwipeAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            try await taskProgressViewModel.refreshTaskProgress(taskType: swipeTaskType.rawValue)
            updateTaskProgress()
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            Logger.success("刷刷赚广告观看完成", category: .adSlot)
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
            Logger.error("处理刷刷赚广告完成失败: \(error.localizedDescription)", category: .adSlot)
        }
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
    
    // MARK: - Status Methods
    
    func getAdSlotStatus() -> String {
        guard adSlotManager.isInitialized else {
            return "广告位管理器未初始化"
        }
        
        let status = adSlotManager.getCacheStatus()
        return """
        广告位状态: \(status.isValid ? "有效" : "无效")
        总广告位数: \(status.totalSlots)
        更新时间: \(status.lastUpdate?.description ?? "无")
        每日任务冷却: \(dailyVM.cooldownRemaining)秒
        """
    }
    
    func refreshAdSlotData() {
        Task {
            Logger.info("手动刷新广告位数据", category: .adSlot)
            await adSlotManager.refreshAdSlotData()
        }
    }
    
    var isAdSlotManagerReady: Bool {
        return adSlotManager.isInitialized
    }
}

// MARK: - TaskTab Enum (保持不变)
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
