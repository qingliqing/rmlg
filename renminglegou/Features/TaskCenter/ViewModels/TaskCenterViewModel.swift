//
//  TaskCenterViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation
import Combine
import UIKit

/// 广告位任务类型枚举
enum AdTaskType: Int, CaseIterable {
    case dailyTask = 1      // 每日任务
    case swipeTask = 2      // 刷刷赚
    case brandTask = 3      // 品牌任务
    
    var displayName: String {
        switch self {
        case .dailyTask: return "每日任务"
        case .swipeTask: return "刷刷赚"
        case .brandTask: return "品牌任务"
        }
    }
}

@MainActor
class TaskCenterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var adConfig: AdConfig?
    @Published var rewardConfigs: [AdRewardConfig] = []
    
    // MARK: - Sub ViewModels
    let dailyVM = DailyTaskViewModel()
    let swipeVM = SwipeTaskViewModel()
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let loadingManager = PureLoadingManager.shared
    private let adSlotManager = AdSlotManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 使用枚举替代硬编码常量
    private let dailyTaskType = AdTaskType.dailyTask
    private let swipeTaskType = AdTaskType.swipeTask
    private let brandTaskType = AdTaskType.brandTask
    
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
            taskService: taskService
        )
        
        // 监听配置变化，重新设置子VM的任务配置
        $adConfig
            .compactMap { $0 }
            .sink { [weak self] config in
                self?.updateSubViewModelsConfig(with: config)
            }
            .store(in: &cancellables)
        
        //        // 分发奖励配置
        $rewardConfigs
            .sink { [weak self] configs in
                self?.dailyVM.updateRewardConfigs(configs)
                self?.swipeVM.updateRewardConfigs(configs)
            }
            .store(in: &cancellables)
    }
    
    private func updateSubViewModelsConfig(with config: AdConfig) {
        // 更新刷刷赚任务配置
        let swipeTask = config.tasks?.first { $0.id == swipeTaskType.rawValue }
        swipeVM.updateTask(swipeTask)
    }
    
    // MARK: - Data Loading Methods
    func loadData() {
        Task {
            isLoading = true
            
            async let adConfigTask: () = loadAdConfig()
            async let rewardConfigsTask: () = loadRewardConfigs()
            
            do {
                _ = try await (adConfigTask, rewardConfigsTask)
                isLoading = false
                
            } catch {
                isLoading = false
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
