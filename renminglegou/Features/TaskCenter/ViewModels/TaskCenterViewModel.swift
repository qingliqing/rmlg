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
    
    // MARK: - Ad Loading States
    @Published var isShowingAd = false
    
    // MARK: - Task Progress Properties (替换原来的 todayAdCount)
    @Published var dailyTaskProgress: AdTaskProgress?
    @Published var swipeTaskProgress: AdTaskProgress?
    @Published var brandTaskProgress: AdTaskProgress?
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
    private let loadingManager = PureLoadingManager.shared
    private var swipeVideoTimer: Timer?
    private let swipeVideoDuration: TimeInterval = 15.0
    private let dailyTaskType = 1 // 每日任务类型
    private let swipeTaskType = 2 // 刷刷赚任务类型
    private let brandTaskType = 3 // 品牌任务类型
    
    // 广告加载超时定时器
    private var adLoadingTimer: Timer?
    private let adLoadingTimeoutDuration: TimeInterval = 10.0
    
    // MARK: - Initialization
    init() {
        setupRewardAdManager()
        loadData()
    }
    
    // MARK: - Setup Methods
    
    // 计算属性
    var dailyTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == dailyTaskType }
    }

    var swipeTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == swipeTaskType }
    }

    var brandTask: AdTask? {
        return adConfig?.tasks?.first { $0.id == brandTaskType }
    }
    
    // 今日观看数量计算属性
    var todayAdCount: Int {
        return dailyTaskProgress?.currentViewCount ?? 0
    }
    
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
            async let taskProgressTask: () = loadAllTaskProgress()
            async let currentPointsTask: () = loadCurrentPoints()
            async let maxPointsTask: () = loadMaxPoints()
            async let adRecordsTask: () = loadAdRecords()
            
            do {
                // 并行加载所有数据
                _ = try await (adConfigTask, rewardConfigsTask, taskProgressTask,
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
    
    /// 加载所有任务进度（初始化时获取任务）
    private func loadAllTaskProgress() async throws {
        // 并行加载三种任务类型的进度
        async let dailyProgressTask = loadTaskProgress(taskType: dailyTaskType)
        async let swipeProgressTask = loadTaskProgress(taskType: swipeTaskType)
        async let brandProgressTask = loadTaskProgress(taskType: brandTaskType)
        
        do {
            let (dailyProgress, swipeProgress, brandProgress) = try await (dailyProgressTask, swipeProgressTask, brandProgressTask)
            
            dailyTaskProgress = dailyProgress
            swipeTaskProgress = swipeProgress
            brandTaskProgress = brandProgress
            
            print("任务进度加载完成 - 每日:\(dailyProgress.currentViewCount), 刷刷赚:\(swipeProgress.currentViewCount), 品牌:\(brandProgress.currentViewCount)")
        } catch {
            print("加载任务进度失败: \(error)")
            throw error
        }
    }
    
    /// 获取单个任务类型的进度（会自动调用receiveTask接口）
    private func loadTaskProgress(taskType: Int) async throws -> AdTaskProgress {
        do {
            let progress = try await taskService.receiveTask(taskType: taskType)
            print("任务类型 \(taskType) 进度: \(progress)")
            return progress
        } catch {
            print("加载任务类型 \(taskType) 进度失败: \(error)")
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
    
    /// 观看每日任务广告（移除领取任务步骤）
    func watchDailyTaskAdvertisement() {
        Task {
            // 直接开始加载广告 - 使用自定义Loading
            startAdLoading()
            
            // 展示激励广告
            showRewardAd()
        }
    }
    
    /// 领取每日任务奖励
    func receiveDailyReward() {
        Task {
            do {
                isGrantingPoints = true
                _ = try await taskService.grantPoints()
                isGrantingPoints = false
                
                // 刷新每日任务进度
                dailyTaskProgress = try await loadTaskProgress(taskType: dailyTaskType)
                
                loadingManager.showSuccess(message: "每日任务奖励领取成功！")
            } catch {
                isGrantingPoints = false
                loadingManager.showError(message: "领取奖励失败")
            }
        }
    }
    
    // MARK: - Swipe Task Methods
    
    /// 开始刷视频任务（移除领取任务步骤）
    func startSwipeVideo() {
        guard !isWatchingSwipeVideo else { return }
        
        Task {
            // 显示Loading，直接开始模拟观看视频
            loadingManager.showLoading(style: .dots)
            
            // 隐藏Loading，开始模拟观看视频
            loadingManager.hideLoading()
            startSwipeVideoProgress()
            
        }
    }
    
    /// 处理刷视频完成（观看后调用获取任务接口）
    func handleSwipeVideoCompletion() {
        Task {
            do {
                // 1. 显示处理Loading
                loadingManager.showLoading(style: .pulse)
                
                // 2. 标记观看完成
                isCompletingView = true
                _ = try await taskService.completeView(taskType: swipeTaskType, adFinishFlag: "completed")
                isCompletingView = false
                
                // 3. 发放积分
                _ = try await taskService.grantPoints()
                
                // 4. 刷新数据（获取最新任务进度）
                async let swipeProgressTask = loadTaskProgress(taskType: swipeTaskType)
                async let currentPointsTask: () = loadCurrentPoints()
                
                let (newProgress, _) = try await (swipeProgressTask, currentPointsTask)
                swipeTaskProgress = newProgress
                
                // 5. 预加载下一个广告
                rewardAdManager.preloadAd()
                
                let reward = currentPoints?.points ?? 5
                loadingManager.showSuccess(message: "刷视频完成，获得\(reward)积分奖励！")
                
            } catch {
                isCompletingView = false
                loadingManager.showError(message: "完成刷视频任务失败")
            }
        }
    }
    
    // MARK: - Brand Task Methods
    
    /// 处理品牌任务
    func handleBrandTaskResult() {
        Task {
            do {
                // 显示加载
                loadingManager.showLoading(style: .bars)
                
                isSubmittingBrandTask = true
                
                // 这里可以调用品牌任务相关的API
                // 暂时使用刷视频的API作为示例
                _ = try await taskService.completeView(taskType: 3, adFinishFlag: "brand_completed")
                _ = try await taskService.grantPoints()
                
                // 刷新广告记录
                _ = try await loadAdRecords()
                
                isSubmittingBrandTask = false
                loadingManager.showSuccess(message: "品牌任务完成，获得奖励！")
                
            } catch {
                isSubmittingBrandTask = false
                loadingManager.showError(message: "品牌任务提交失败")
            }
        }
    }
    
    // MARK: - Ad Loading Management Methods
    
    /// 开始广告加载状态 - 使用自定义Loading
    private func startAdLoading() {
        // 显示圆环旋转Loading，比较适合广告加载
        loadingManager.showLoading(style: .circle)
        
        // 设置广告加载超时
        adLoadingTimer = Timer.scheduledTimer(withTimeInterval: adLoadingTimeoutDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleAdLoadingTimeout()
            }
        }
        
        print("开始加载广告...")
    }
    
    /// 停止广告加载状态
    private func stopAdLoading() {
        loadingManager.hideLoading()
        adLoadingTimer?.invalidate()
        adLoadingTimer = nil
        
        print("停止广告加载状态")
    }
    
    /// 处理广告加载超时
    private func handleAdLoadingTimeout() {
        stopAdLoading()
        loadingManager.showError(message: "广告加载超时，请稍后重试")
    }
    
    // MARK: - Ad Management Methods
    
    /// 展示激励广告
    private func showRewardAd() {
        // 使用新的 UIWindowScene API
        guard let windowScene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
              let window = windowScene.windows.first(where: \.isKeyWindow) else {
            stopAdLoading()
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        guard let viewController = window.rootViewController else {
            stopAdLoading()
            loadingManager.showError(message: "无法获取视图控制器")
            return
        }
        
        // 展示广告
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
        guard let task = dailyTask else { return false }
        let currentCount = dailyTaskProgress?.currentViewCount ?? 0
        return currentCount < task.totalAdCount && !loadingManager.isShowingLoading && !isShowingAd
    }
    
    /// 是否正在处理广告相关操作
    var isHandlingAd: Bool {
        return loadingManager.isShowingLoading || isShowingAd
    }
    
    // MARK: - Deinitializer
    deinit {
        swipeVideoTimer?.invalidate()
        adLoadingTimer?.invalidate()
    }
}

// MARK: - RewardAdManagerDelegate
extension TaskCenterViewModel: RewardAdManagerDelegate {
    
    nonisolated func rewardAdDidLoad() {
        print("激励广告加载成功")
        // 广告加载成功，等待展示
    }
    
    nonisolated func rewardAdDidFailToLoad(error: Error?) {
        Task { @MainActor in
            stopAdLoading()
            loadingManager.showError(message: "广告加载失败")
        }
    }
    
    nonisolated func rewardAdDidShow() {
        print("激励广告开始展示")
        Task { @MainActor in
            stopAdLoading() // 广告开始展示，停止loading状态
            isShowingAd = true
        }
    }
    
    nonisolated func rewardAdDidFailToShow(error: Error) {
        Task { @MainActor in
            stopAdLoading()
            isShowingAd = false
            loadingManager.showError(message: "广告展示失败")
        }
    }
    
    nonisolated func rewardAdDidClick() {
        print("用户点击了广告")
    }
    
    nonisolated func rewardAdDidClose() {
        print("广告关闭")
        Task { @MainActor in
            isShowingAd = false
            // 广告关闭后可以继续其他逻辑
        }
    }
    
    nonisolated func rewardAdDidRewardUser(verified: Bool) {
        if verified {
            print("用户获得广告奖励，验证通过")
            // 处理广告观看完成逻辑
            Task { @MainActor in
                isShowingAd = false
                await handleAdWatchCompleted()
            }
        } else {
            Task { @MainActor in
                isShowingAd = false
                loadingManager.showError(message: "广告奖励验证失败")
            }
        }
    }
    
    nonisolated func rewardAdDidFailToReward(error: Error?) {
        Task { @MainActor in
            isShowingAd = false
            loadingManager.showError(message: "广告奖励发放失败")
        }
    }
    
    nonisolated func rewardAdDidFinishPlaying(error: Error?) {
        if error != nil {
            Task { @MainActor in
                isShowingAd = false
                loadingManager.showError(message: "广告播放失败")
            }
        } else {
            print("广告播放完成")
            Task { @MainActor in
                isShowingAd = false
            }
        }
    }
    
    /// 处理广告观看完成后的逻辑（观看后调用获取任务接口）
    private func handleAdWatchCompleted() async {
        do {
            // 1. 显示处理Loading
            loadingManager.showLoading(style: .pulse)
            
            // 2. 标记观看完成
            isCompletingView = true
            _ = try await taskService.completeView(taskType: dailyTaskType, adFinishFlag: "ad_completed")
            isCompletingView = false
            
            // 3. 发放积分
            _ = try await taskService.grantPoints()
            
            // 4. 刷新数据（获取最新任务进度）
            async let dailyProgressTask = loadTaskProgress(taskType: dailyTaskType)
            async let currentPointsTask: () = loadCurrentPoints()
            
            let (newProgress, _) = try await (dailyProgressTask, currentPointsTask)
            dailyTaskProgress = newProgress
            
            // 5. 预加载下一个广告
            rewardAdManager.preloadAd()
            
            loadingManager.showSuccess(message: "广告观看完成，积分已发放！")
            
        } catch {
            isCompletingView = false
            loadingManager.showError(message: "处理广告完成失败")
        }
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
