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
    let rewardAdViewModel = RewardAdViewModel()
    let swipeVideoViewModel = SwipeTaskViewModel()
    
    // MARK: - Task Config Properties
    @Published var adConfig: AdConfig?
    @Published var rewardConfigs: [AdRewardConfig] = []
    @Published var currentPoints: AdPoints?
    @Published var maxPoints: AdPoints?
    @Published var adRecords: Int = 0
    @Published var isSubmittingBrandTask = false
    
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
    
    var todayAdCount: Int {
        return taskProgressViewModel.todayAdCount
    }
    
    var canWatchDailyAd: Bool {
        guard let task = dailyTask else { return false }
        let currentCount = taskProgressViewModel.dailyTaskProgress?.currentViewCount ?? 0
        return currentCount < task.totalAdCount && !loadingManager.isShowingLoading && !rewardAdViewModel.isShowingAd
    }
    
    var isHandlingAd: Bool {
        return loadingManager.isShowingLoading || rewardAdViewModel.isShowingAd
    }
    
    // MARK: - Initialization
    init() {
        setupSubViewModels()
        loadData()
    }
    
    // MARK: - Setup Methods
    
    private func setupSubViewModels() {
        // 设置激励广告完成回调
        rewardAdViewModel.onAdWatchCompleted = { [weak self] in
            await self?.handleDailyAdWatchCompleted()
        }
        
        // 设置刷视频完成回调
        swipeVideoViewModel.onVideoCompleted = { [weak self] in
            await self?.handleSwipeVideoCompletion()
        }
    }
    
    // MARK: - Data Loading Methods
    
    func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            async let adConfigTask: () = loadAdConfig()
            async let rewardConfigsTask: () = loadRewardConfigs()
            async let taskProgressTask: () = taskProgressViewModel.loadAllTaskProgress()
            async let maxPointsTask: () = loadMaxPoints()
            async let adRecordsTask: () = loadAdRecords()
            
            do {
                _ = try await (adConfigTask, rewardConfigsTask, taskProgressTask, maxPointsTask, adRecordsTask)
                isLoading = false
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
    
    func watchDailyTaskAdvertisement() {
        rewardAdViewModel.watchRewardAd()
    }
    
    func receiveDailyReward() {
        Task {
            do {
                try await taskProgressViewModel.refreshTaskProgress(taskType: dailyTaskType)
                loadingManager.showSuccess(message: "每日任务奖励领取成功！")
            } catch {
                loadingManager.showError(message: "领取奖励失败")
            }
        }
    }
    
    private func handleDailyAdWatchCompleted() async {
        do {
            loadingManager.showLoading(style: .pulse)
            
            try await taskProgressViewModel.completeViewTask(taskType: dailyTaskType, adFinishFlag: "ad_completed")
            try await taskProgressViewModel.refreshTaskProgress(taskType: dailyTaskType)
            
            receiveDailyReward()
            // 预加载下一个广告
            RewardAdManager.shared.preloadAd()
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            
        } catch {
            loadingManager.showError(message: "处理广告完成失败")
        }
    }
    
    // MARK: - Swipe Task Methods
    
    func startSwipeVideo() {
        swipeVideoViewModel.startSwipeVideo()
    }
    
    private func handleSwipeVideoCompletion() async {
        
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
