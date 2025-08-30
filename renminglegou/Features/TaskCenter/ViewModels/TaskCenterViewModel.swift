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
    @Published var currentPoints: AdPoints?
    @Published var maxPoints: AdPoints?
    @Published var adRecords: Int = 0
    @Published var isSubmittingBrandTask = false
    
    @Published var dailyViewCount: Int = 0
    @Published var dailyTaskProgress: AdTaskProgress?
    @Published var swipeTaskProgress: AdTaskProgress?
    @Published var brandTaskProgress: AdTaskProgress?
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let loadingManager = PureLoadingManager.shared
    
    private let dailyTaskType = 1
    private let swipeTaskType = 2
    private let brandTaskType = 3
    
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
    }
    
    // MARK: - Data Loading Methods
    
    func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            async let adConfigTask: () = loadAdConfig()
            async let rewardConfigsTask: () = loadRewardConfigs()
            async let taskProgressTask: () = loadAllTaskProgress()
            async let maxPointsTask: () = loadMaxPoints()
            async let adRecordsTask: () = loadAdRecords()
            
            do {
                _ = try await (adConfigTask, rewardConfigsTask, taskProgressTask, maxPointsTask, adRecordsTask)
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
    
    private func loadMaxPoints() async throws {
        let points = try await taskService.getMaxPoints()
        maxPoints = points
    }
    
    private func loadAdRecords() async throws {
        let records = try await taskService.getAdRecords()
        adRecords = records
    }
    
    // MARK: - Daily Task Methods
    
    func watchDailyTaskAd() {
        dailyVM.watchRewardAd()
    }
    
    private func handleDailyAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            try await taskProgressViewModel.completeViewTask(taskType: dailyTaskType, adFinishFlag: "ad_completed")
            
            // 2. 刷新进度并领取奖励（合并操作）
            try await taskProgressViewModel.refreshTaskProgress(taskType: dailyTaskType)
            
            updateTaskProgress()
            
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
    
    /// 刷刷赚广告完成
    private func handleSwipeAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            try await taskProgressViewModel.completeViewTask(taskType: swipeTaskType, adFinishFlag: "ad_completed")
            
            // 2. 刷新进度并领取奖励（合并操作）
            try await taskProgressViewModel.refreshTaskProgress(taskType: swipeTaskType)
            
            updateTaskProgress()
            
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
