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
    @Published var taskProgresses: [Int: AdTaskProgress] = [:]
    @Published var isLoading = false
    @Published var isCompletingView = false
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    
    // MARK: - Public Methods
    
    /// 加载指定任务类型的进度
    func loadTaskProgress(taskType: Int) async throws {
        let progress = try await taskService.receiveTask(taskType: taskType)
        taskProgresses[taskType] = progress
    }
    
    /// 批量加载任务进度
    func loadTaskProgresses(taskTypes: [Int]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for taskType in taskTypes {
                group.addTask {
                    try await self.loadTaskProgress(taskType: taskType)
                }
            }
            try await group.waitForAll()
        }
    }
    
    /// 完成观看任务
    func completeViewTask(taskType: Int, adFinishFlag: String) async throws {
        isCompletingView = true
        defer { isCompletingView = false }
        
        _ = try await taskService.completeView(taskType: taskType, adFinishFlag: adFinishFlag)
    }
    
    /// 刷新特定任务进度
    func refreshTaskProgress(taskType: Int) async throws {
        try await loadTaskProgress(taskType: taskType)
    }
    
    /// 获取指定任务的进度
    func getProgress(for taskType: Int) -> AdTaskProgress? {
        return taskProgresses[taskType]
    }
    
    /// 获取指定任务的当前观看次数
    func getCurrentViewCount(for taskType: Int) -> Int {
        return taskProgresses[taskType]?.currentViewCount ?? 0
    }
}
