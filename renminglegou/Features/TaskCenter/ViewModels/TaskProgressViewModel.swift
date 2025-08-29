//
//  TaskProgressViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/29.
//

import Foundation
import Combine

@MainActor
final class TaskProgressViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var dailyTaskProgress: AdTaskProgress?
    @Published var swipeTaskProgress: AdTaskProgress?
    @Published var brandTaskProgress: AdTaskProgress?
    
    @Published var isReceivingTask = false
    @Published var isCompletingView = false
    @Published var isGrantingPoints = false
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    
    private let dailyTaskType = 1
    private let swipeTaskType = 2
    private let brandTaskType = 3
    
    // MARK: - Computed Properties
    var todayAdCount: Int {
        return dailyTaskProgress?.currentViewCount ?? 0
    }
    
    // MARK: - Public Methods
    
    /// 加载所有任务进度
    func loadAllTaskProgress() async throws {
        async let dailyProgressTask = loadTaskProgress(taskType: dailyTaskType)
        async let swipeProgressTask = loadTaskProgress(taskType: swipeTaskType)
        async let brandProgressTask = loadTaskProgress(taskType: brandTaskType)
        
        let (dailyProgress, swipeProgress, brandProgress) = try await (dailyProgressTask, swipeProgressTask, brandProgressTask)
        
        dailyTaskProgress = dailyProgress
        swipeTaskProgress = swipeProgress
        brandTaskProgress = brandProgress
    }
    
    /// 完成观看任务
    func completeViewTask(taskType: Int, adFinishFlag: String) async throws {
        isCompletingView = true
        defer { isCompletingView = false }
        
        _ = try await taskService.completeView(taskType: taskType, adFinishFlag: adFinishFlag)
    }
    
    
    /// 刷新特定任务进度
    func refreshTaskProgress(taskType: Int) async throws {
        let progress = try await loadTaskProgress(taskType: taskType)
        
        switch taskType {
        case dailyTaskType:
            dailyTaskProgress = progress
        case swipeTaskType:
            swipeTaskProgress = progress
        case brandTaskType:
            brandTaskProgress = progress
        default:
            break
        }
    }
    
    // MARK: - Private Methods
    private func loadTaskProgress(taskType: Int) async throws -> AdTaskProgress {
        return try await taskService.receiveTask(taskType: taskType)
    }
}
