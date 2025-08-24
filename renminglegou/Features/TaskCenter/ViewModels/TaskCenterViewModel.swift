//
//  TaskCenterViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation
import Combine
import UIKit

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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccessAlert = false
    @Published var successMessage: String = ""
    
    // MARK: - Daily Task Properties
    @Published var todayAdCount: Int = 0
    @Published var isReceivingTask = false
    @Published var isCompletingView = false
    @Published var isGrantingPoints = false
    
    // MARK: - Swipe Task Properties
    @Published var adConfig: AdConfig?
    @Published var rewardConfigs: [AdRewardConfig] = []
    @Published var currentPoints: AdPoints?
    @Published var maxPoints: AdPoints?
    @Published var isWatchingSwipeVideo = false
    @Published var swipeVideoProgress: Double = 0.0
    
    // MARK: - Brand Task Properties
    @Published var adRecords: Int = 0
    @Published var isSubmittingBrandTask = false
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let rewardAdManager = RewardAdManager.shared
    private var swipeVideoTimer: Timer?
    private let swipeVideoDuration: TimeInterval = 15.0
    private let dailyTaskType = 1 // 每日任务类型
    private let swipeTaskType = 2 // 刷刷赚任务类型
    
    // MARK: - Initialization
    init() {
        setupRewardAdManager()
        loadData()
    }
    
    // MARK: - Setup Methods
    
    private func setupRewardAdManager() {
        rewardAdManager.delegate = self
        // 预加载激励广告
        rewardAdManager.preloadAd()
    }
    
    // MARK: - Data Loading Methods
    
    /// 加载所有任务中心数据
    func loadData() {
        Task {
            isLoading = true
            errorMessage = nil
            
            async let adConfigTask: () = loadAdConfig()
            async let rewardConfigsTask: () = loadRewardConfigs()
            async let todayCountTask: () = loadTodayAdCount(taskType: dailyTaskType)
            async let currentPointsTask: () = loadCurrentPoints()
            async let maxPointsTask: () = loadMaxPoints()
            async let adRecordsTask: () = loadAdRecords()
            
            do {
                // 并行加载所有数据
                _ = try await (adConfigTask, rewardConfigsTask, todayCountTask,
                              currentPointsTask, maxPointsTask, adRecordsTask)
                
                isLoading = false
                print("所有数据加载完成")
            } catch {
                isLoading = false
                showErrorMessage("数据加载失败: \(error.localizedDescription)")
            }
        }
    }
    
    
    // MARK: - Individual Data Loading Methods
    
    private func loadAdConfig() async throws {
        do {
            let config = try await taskService.getAdConfig()
            adConfig = config
            print("广告配置加载成功: \(config)")
        } catch {
            print("加载广告配置失败: \(error)")
            throw error
        }
    }
    
    private func loadRewardConfigs() async throws {
        do {
            let configs = try await taskService.getRewardConfigs()
            rewardConfigs = configs
            print("奖励配置加载成功，共\(configs.count)个配置")
        } catch {
            print("加载奖励配置失败: \(error)")
            throw error
        }
    }
    
    private func loadTodayAdCount(taskType: Int) async throws {
        do {
            let count = try await taskService.getTodayCount(taskType: taskType)
            todayAdCount = count
            print("今日广告观看数量: \(count)")
        } catch {
            print("加载今日广告观看数量失败: \(error)")
            throw error
        }
    }
    
    private func loadCurrentPoints() async throws {
        do {
            let points = try await taskService.getCurrentPoints()
            currentPoints = points
            print("当前积分: \(points)")
        } catch {
            print("加载当前积分失败: \(error)")
            throw error
        }
    }
    
    private func loadMaxPoints() async throws {
        do {
            let points = try await taskService.getMaxPoints()
            maxPoints = points
            print("最大积分: \(points)")
        } catch {
            print("加载最大积分失败: \(error)")
            throw error
        }
    }
    
    private func loadAdRecords() async throws {
        do {
            let records = try await taskService.getAdRecords()
            adRecords = records
            print("广告记录: \(records)")
        } catch {
            print("加载广告记录失败: \(error)")
            throw error
        }
    }
    
    // MARK: - Daily Task Methods
    
    /// 观看每日任务广告
    func watchDailyTaskAdvertisement() {
        Task {
            do {
                // 1. 先领取任务
                isReceivingTask = true
                _ = try await taskService.receiveTask(taskType: dailyTaskType)
                isReceivingTask = false
                
                // 2. 展示激励广告
                showRewardAd()
                
            } catch {
                isReceivingTask = false
                showErrorMessage("领取每日任务失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 领取每日任务奖励
    func receiveDailyReward() {
        Task {
            do {
                isGrantingPoints = true
                _ = try await taskService.grantPoints()
                isGrantingPoints = false
                
                // 刷新今日观看数量
                _ = try await loadTodayAdCount(taskType: dailyTaskType)
                
                showSuccessMessage("每日任务奖励领取成功！")
            } catch {
                isGrantingPoints = false
                showErrorMessage("领取奖励失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Swipe Task Methods
    
    /// 开始刷视频任务
    func startSwipeVideo() {
        guard !isWatchingSwipeVideo else { return }
        
        Task {
            do {
                // 1. 领取刷视频任务
                isReceivingTask = true
                _ = try await taskService.receiveTask(taskType: swipeTaskType)
                isReceivingTask = false
                
                // 2. 开始模拟观看视频（实际项目中这里是展示广告）
                startSwipeVideoProgress()
                
            } catch {
                isReceivingTask = false
                showErrorMessage("领取刷视频任务失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 处理刷视频完成
    func handleSwipeVideoCompletion() {
        Task {
            do {
                // 1. 标记观看完成
                isCompletingView = true
                _ = try await taskService.completeView(taskType: swipeTaskType, adFinishFlag: "completed")
                isCompletingView = false
                
                // 2. 发放积分
                _ = try await taskService.grantPoints()
                
                // 3. 刷新数据
                async let todayCountTask: () = loadTodayAdCount(taskType: swipeTaskType)
                async let currentPointsTask: () = loadCurrentPoints()
                _ = try await (todayCountTask, currentPointsTask)
                
                // 4. 预加载下一个广告
                rewardAdManager.preloadAd()
                
                let reward = currentPoints?.points ?? 5
                showSuccessMessage("刷视频完成，获得\(reward)积分奖励！")
                
            } catch {
                isCompletingView = false
                showErrorMessage("完成刷视频任务失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Brand Task Methods
    
    /// 处理品牌任务
    func handleBrandTaskResult() {
        Task {
            do {
                isSubmittingBrandTask = true
                
                // 这里可以调用品牌任务相关的API
                // 暂时使用刷视频的API作为示例
                _ = try await taskService.completeView(taskType: 3, adFinishFlag: "brand_completed")
                _ = try await taskService.grantPoints()
                
                // 刷新广告记录
                _ = try await loadAdRecords()
                
                isSubmittingBrandTask = false
                showSuccessMessage("品牌任务完成，获得奖励！")
                
            } catch {
                isSubmittingBrandTask = false
                showErrorMessage("品牌任务提交失败: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Ad Management Methods
    
    /// 展示激励广告
    private func showRewardAd() {
        // 使用新的 UIWindowScene API
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            return
        }
        
        guard let viewController = window.rootViewController else {
            showErrorMessage("无法获取视图控制器")
            return
        }
        
        rewardAdManager.showAd(from: viewController)
    }
    
    // MARK: - Video Progress Methods
    
    private func startSwipeVideoProgress() {
        isWatchingSwipeVideo = true
        swipeVideoProgress = 0.0
        
        print("开始刷视频...")
        
        swipeVideoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateSwipeVideoProgress()
            }
        }
    }
    
    private func updateSwipeVideoProgress() {
        swipeVideoProgress += 0.1 / swipeVideoDuration
        
        if swipeVideoProgress >= 1.0 {
            swipeVideoProgress = 1.0
            stopSwipeVideo()
            // 视频观看完成，处理完成逻辑
            handleSwipeVideoCompletion()
        }
    }
    
    private func stopSwipeVideo() {
        isWatchingSwipeVideo = false
        swipeVideoProgress = 0.0
        swipeVideoTimer?.invalidate()
        swipeVideoTimer = nil
    }
    
    // MARK: - Helper Methods
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        print("Error: \(message)")
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccessAlert = true
        print("Success: \(message)")
    }
    
    // MARK: - Computed Properties
    
    /// 每日任务是否可以观看广告
    var canWatchDailyAd: Bool {
        return todayAdCount < 5 // 假设每日限制5次
    }
    
    // MARK: - Deinitializer
    deinit {
        swipeVideoTimer?.invalidate()
    }
}

// MARK: - RewardAdManagerDelegate
extension TaskCenterViewModel: RewardAdManagerDelegate {
    
    nonisolated func rewardAdDidLoad() {
        print("激励广告加载成功")
    }
    
    nonisolated func rewardAdDidFailToLoad(error: Error?) {
        Task { @MainActor in
            showErrorMessage("广告加载失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
    
    nonisolated func rewardAdDidShow() {
        print("激励广告开始展示")
    }
    
    nonisolated func rewardAdDidFailToShow(error: Error) {
        Task { @MainActor in
            showErrorMessage("广告展示失败: \(error.localizedDescription)")
        }
    }
    
    nonisolated func rewardAdDidClick() {
        print("用户点击了广告")
    }
    
    nonisolated func rewardAdDidClose() {
        print("广告关闭")
        // 广告关闭后可以继续其他逻辑
    }
    
    nonisolated func rewardAdDidRewardUser(verified: Bool) {
        if verified {
            print("用户获得广告奖励，验证通过")
            // 处理广告观看完成逻辑
            Task { @MainActor in
                await handleAdWatchCompleted()
            }
        } else {
            Task { @MainActor in
                showErrorMessage("广告奖励验证失败")
            }
        }
    }
    
    nonisolated func rewardAdDidFailToReward(error: Error?) {
        Task { @MainActor in
            showErrorMessage("广告奖励发放失败: \(error?.localizedDescription ?? "未知错误")")
        }
    }
    
    nonisolated func rewardAdDidFinishPlaying(error: Error?) {
        if let error = error {
            Task { @MainActor in
                showErrorMessage("广告播放失败: \(error.localizedDescription)")
            }
        } else {
            print("广告播放完成")
        }
    }
    
    /// 处理广告观看完成后的逻辑
    private func handleAdWatchCompleted() async {
        do {
            // 1. 标记观看完成
            isCompletingView = true
            _ = try await taskService.completeView(taskType: dailyTaskType, adFinishFlag: "ad_completed")
            isCompletingView = false
            
            // 2. 发放积分
            _ = try await taskService.grantPoints()
            
            // 3. 刷新数据
            async let todayCountTask: () = loadTodayAdCount(taskType: dailyTaskType)
            async let currentPointsTask: () = loadCurrentPoints()
            _ = try await (todayCountTask, currentPointsTask)
            
            showSuccessMessage("广告观看完成，积分已发放！")
            
        } catch {
            isCompletingView = false
            showErrorMessage("处理广告完成失败: \(error.localizedDescription)")
        }
    }
}
