//
//  TaskCenterViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation
import Combine

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

@MainActor
class TaskCenterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var taskInfo: TaskInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isReceiving = false
    @Published var showSuccessAlert = false
    
    // MARK: - Swipe Task Properties
    @Published var swipeTaskInfo: SwipeTaskInfo?
    @Published var isWatchingSwipeVideo = false
    @Published var swipeVideoProgress: Double = 0.0
    
    // MARK: - Brand Task Properties
    @Published var brandTaskInfo: BrandTaskInfo?
    @Published var isSubmittingBrandTask = false
    
    // MARK: - Private Properties
    private let service = TaskCenterService()
    private var swipeVideoTimer: Timer?
    private let swipeVideoDuration: TimeInterval = 15.0 // 刷视频需要观看15秒
    
    // MARK: - Initialization
    init() {
        loadData()
    }
    
    // MARK: - Public Methods
    
    /// Load all task center data
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        // 模拟数据加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.taskInfo = TaskInfo(
                taskId: "daily_task_001",
                completedCount: 2,
                totalCount: 5
            )
            
            self.swipeTaskInfo = SwipeTaskInfo(
                taskId: "swipe_task_001",
                todayWatchCount: 3,
                dailyLimit: 10,
                rewardPerVideo: 5
            )
            
            self.brandTaskInfo = BrandTaskInfo(
                taskId: "brand_task_001",
                title: "品牌推广任务",
                description: "完成品牌任务获得丰厚奖励",
                reward: 50,
                isCompleted: false
            )
            
            self.isLoading = false
        }
    }
    
    // MARK: - Daily Task Methods
    
    /// Watch advertisement for daily task
    func watchAdvertisement() {
        guard let taskInfo = taskInfo else { return }
        
        print("开始观看广告视频...")
        
        // 模拟广告播放
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // 更新任务进度
            let newCompletedCount = min(taskInfo.completedCount + 1, taskInfo.totalCount)
            self.taskInfo = TaskInfo(
                taskId: taskInfo.taskId,
                completedCount: newCompletedCount,
                totalCount: taskInfo.totalCount
            )
            
            self.showSuccessMessage("广告观看完成！")
        }
    }
    
    /// Receive daily task reward
    func receiveReward() {
        guard let taskInfo = taskInfo, taskInfo.canReceiveReward else { return }
        
        isReceiving = true
        
        // 模拟领取奖励
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isReceiving = false
            self.showSuccessAlert = true
            
            // 重置任务或标记为已完成
            self.taskInfo = TaskInfo(
                taskId: taskInfo.taskId,
                completedCount: taskInfo.totalCount,
                totalCount: taskInfo.totalCount
            )
            
            print("每日任务奖励领取成功！")
        }
    }
    
    // MARK: - Swipe Task Methods
    
    /// Start watching swipe videos
    func startSwipeVideo() {
        guard let swipeInfo = swipeTaskInfo, !isWatchingSwipeVideo else { return }
        
        // Check if user has reached daily limit
        if swipeInfo.todayWatchCount >= swipeInfo.dailyLimit {
            showErrorMessage("今日刷视频次数已达上限")
            return
        }
        
        isWatchingSwipeVideo = true
        swipeVideoProgress = 0.0
        
        print("开始刷视频...")
        
        // Start video progress timer
        swipeVideoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSwipeVideoProgress()
            }
        }
    }
    
    /// Handle swipe video completion
    func handleSwipeVideoResult() {
        guard isWatchingSwipeVideo else { return }
        
        stopSwipeVideo()
        
        // 更新刷视频次数
        if let swipeInfo = swipeTaskInfo {
            let newWatchCount = swipeInfo.todayWatchCount + 1
            self.swipeTaskInfo = SwipeTaskInfo(
                taskId: swipeInfo.taskId,
                todayWatchCount: newWatchCount,
                dailyLimit: swipeInfo.dailyLimit,
                rewardPerVideo: swipeInfo.rewardPerVideo
            )
            
            showSuccessMessage("刷视频完成，获得\(swipeInfo.rewardPerVideo)金币奖励！")
        }
    }
    
    // MARK: - Brand Task Methods
    
    /// Handle brand task submission
    func handleBrandTaskResult() {
        guard let brandInfo = brandTaskInfo, !brandInfo.isCompleted else { return }
        
        isSubmittingBrandTask = true
        
        // 模拟品牌任务提交
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.isSubmittingBrandTask = false
            
            // 标记任务为已完成
            self.brandTaskInfo = BrandTaskInfo(
                taskId: brandInfo.taskId,
                title: brandInfo.title,
                description: brandInfo.description,
                reward: brandInfo.reward,
                isCompleted: true
            )
            
            self.showSuccessMessage("品牌任务完成，获得\(brandInfo.reward)金币奖励！")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSwipeVideoProgress() {
        swipeVideoProgress += 0.1 / swipeVideoDuration
        
        if swipeVideoProgress >= 1.0 {
            swipeVideoProgress = 1.0
            // Video watching completed
            handleSwipeVideoResult()
        }
    }
    
    private func stopSwipeVideo() {
        isWatchingSwipeVideo = false
        swipeVideoProgress = 0.0
        swipeVideoTimer?.invalidate()
        swipeVideoTimer = nil
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        print("Success: \(message)")
        // 可以在这里添加成功提示的UI显示逻辑
    }
    
    // MARK: - Deinitializer
    deinit {
        swipeVideoTimer?.invalidate()
    }
}

// MARK: - Supporting Models
struct TaskInfo {
    let taskId: String
    let completedCount: Int
    let totalCount: Int
    
    var canReceiveReward: Bool {
        return completedCount > 0 && completedCount < totalCount
    }
    
    var allCompleted: Bool {
        return completedCount >= totalCount
    }
}

struct SwipeTaskInfo {
    let taskId: String
    let todayWatchCount: Int
    let dailyLimit: Int
    let rewardPerVideo: Int
    
    var canWatch: Bool {
        return todayWatchCount < dailyLimit
    }
    
    var remainingCount: Int {
        return max(0, dailyLimit - todayWatchCount)
    }
}

struct BrandTaskInfo {
    let taskId: String
    let title: String
    let description: String
    let reward: Int
    let isCompleted: Bool
}

