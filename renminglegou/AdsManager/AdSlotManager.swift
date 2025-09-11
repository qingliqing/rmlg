//
//  AdSlotManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/9/10.
//

import Foundation
import Combine

/// Ad Slot Manager - 独立管理广告位的获取、缓存和分配
@MainActor
class AdSlotManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = AdSlotManager()
    
    // MARK: - Published Properties
    @Published var isInitialized = false
    @Published var isLoading = false
    @Published var lastUpdateTime: Date?
    
    // MARK: - Private Properties
    private let taskService = TaskCenterService.shared
    private let userDefaults = UserDefaults.standard
    
    // 广告位缓存，按任务类型存储
    private var adSlotCache: [Int: [String]] = [:]
    
    // 广告平台配置
    private var adPlatformConfig: AdCodeConfig?
    
    // 缓存key
    private let cacheKey = "ad_slot_cache"
    private let lastUpdateKey = "ad_slot_last_update"
    private let cacheValidityHours = 0 // 缓存有效期24小时
    
    // MARK: - Initialization
    private init() {
        loadCachedData()
    }
    
    // MARK: - Public Methods
    
    /// APP启动时调用，初始化广告位数据
    func initializeOnAppLaunch() async {
        Logger.adSlot("开始初始化广告位数据")
        
        // 检查缓存是否有效
        if isCacheValid() {
            Logger.success("使用缓存数据", category: .adSlot)
            isInitialized = true
            return
        }
        
        // 缓存无效或不存在，重新获取
        await refreshAdSlotData()
    }
    
    /// 强制刷新广告位数据
    func refreshAdSlotData() async {
        isLoading = true
        
        do {
            // 获取广告平台配置
            let config = try await taskService.getAdCodeList()
            adPlatformConfig = config
            
            // 解析并缓存广告位
            parseAndCacheAdSlots(from: config)
            
            // 保存到本地缓存
            saveCacheData()
            
            isInitialized = true
            lastUpdateTime = Date()
            
            Logger.success("广告位数据刷新完成", category: .adSlot)
            
        } catch {
            Logger.error("获取广告位数据失败: \(error.localizedDescription)", category: .adSlot)
        }
        
        isLoading = false
    }
    
    /// 获取指定任务类型的观看间隔时间（枚举版本）
    func getWatchInterval(for taskType: AdSlotTaskType) -> Int {
        return getWatchInterval(for: taskType.rawValue)
    }
    
    /// 获取指定任务类型的观看间隔时间（Int版本）
    func getWatchInterval(for taskType: Int) -> Int {
        guard let config = adPlatformConfig else {
            Logger.warning("广告平台配置未加载，返回默认间隔时间", category: .adSlot)
            return 0
        }
        
        let interval = config.getWatchInterval(for: taskType)
        Logger.info("任务类型 \(taskType) 的观看间隔: \(interval)秒", category: .adSlot)
        return interval
    }
    
    /// 获取指定任务类型的当前广告位ID
    func getCurrentAdSlotId(for taskType: AdSlotTaskType, currentViewCount: Int = 0) -> String? {
        return getCurrentAdSlotId(for: taskType.rawValue, currentViewCount: currentViewCount)
    }
    
    /// 获取指定任务类型的当前广告位ID（使用Int参数兼容旧代码）
    func getCurrentAdSlotId(for taskType: Int, currentViewCount: Int = 0) -> String? {
        guard let adSlots = adSlotCache[taskType], !adSlots.isEmpty else {
            Logger.warning("任务类型 \(taskType) 没有可用的广告位", category: .adSlot)
            return nil
        }
        
        let selectedAdSlot: String
        let taskTypeEnum = AdSlotTaskType(rawValue: taskType)
        
        // 根据任务类型选择不同的获取策略
        if taskTypeEnum?.requiresSequentialAccess == true {
            // 每日任务和刷刷赚使用顺序选择（基于观看次数）
            let adSlotIndex = currentViewCount % adSlots.count
            selectedAdSlot = adSlots[adSlotIndex]
            Logger.adSlot("任务类型 \(taskTypeEnum?.displayName ?? "未知"): 已观看 \(currentViewCount) 次，顺序选择广告位[\(adSlotIndex)]: \(selectedAdSlot)")
        } else {
            // 开屏、Banner、信息流使用随机选择
            let randomIndex = Int.random(in: 0..<adSlots.count)
            selectedAdSlot = adSlots[randomIndex]
            Logger.adSlot("任务类型 \(taskTypeEnum?.displayName ?? "未知"): 随机选择广告位[\(randomIndex)]: \(selectedAdSlot)")
        }
        
        return selectedAdSlot
    }
    
    /// 获取指定任务类型的下一个广告位ID（枚举版本）
    func getNextAdSlotId(for taskType: AdSlotTaskType, currentViewCount: Int) -> String? {
        return getNextAdSlotId(for: taskType.rawValue, currentViewCount: currentViewCount)
    }
    
    /// 获取指定任务类型的下一个广告位ID（仅适用于需要预加载的任务类型）
    func getNextAdSlotId(for taskType: Int, currentViewCount: Int) -> String? {
        let taskTypeEnum = AdSlotTaskType(rawValue: taskType)
        
        // 只有需要顺序访问的任务类型才支持预加载
        guard taskTypeEnum?.supportsPreloading == true else {
            Logger.info("任务类型 \(taskTypeEnum?.displayName ?? "未知") 不需要预加载功能", category: .adSlot)
            return nil
        }
        
        guard let adSlots = adSlotCache[taskType], !adSlots.isEmpty else {
            return nil
        }
        
        let nextCount = currentViewCount + 1
        let nextAdSlotIndex = nextCount % adSlots.count
        let nextAdSlot = adSlots[nextAdSlotIndex]
        
        Logger.adSlot("任务类型 \(taskTypeEnum?.displayName ?? "未知") 下一个广告位: \(nextAdSlot)")
        
        return nextAdSlot
    }
    
    /// 获取指定任务类型的所有广告位列表（枚举版本）
    func getAllAdSlots(for taskType: AdSlotTaskType) -> [String] {
        return getAllAdSlots(for: taskType.rawValue)
    }
    
    /// 获取指定任务类型的所有广告位列表
    func getAllAdSlots(for taskType: Int) -> [String] {
        return adSlotCache[taskType] ?? []
    }
    
    /// 检查指定任务类型是否有可用的广告位（枚举版本）
    func hasAvailableAdSlots(for taskType: AdSlotTaskType) -> Bool {
        return hasAvailableAdSlots(for: taskType.rawValue)
    }
    
    /// 检查指定任务类型是否有可用的广告位
    func hasAvailableAdSlots(for taskType: Int) -> Bool {
        return !(adSlotCache[taskType]?.isEmpty ?? true)
    }
    
    /// 获取广告位缓存状态信息
    func getCacheStatus() -> (isValid: Bool, lastUpdate: Date?, totalSlots: Int) {
        let totalSlots = adSlotCache.values.reduce(0) { $0 + $1.count }
        return (isCacheValid(), lastUpdateTime, totalSlots)
    }
    
    // MARK: - Private Methods
    
    /// 解析广告平台配置并缓存广告位（项目确定为iOS）
    private func parseAndCacheAdSlots(from config: AdCodeConfig) {
        adSlotCache.removeAll()
        
        // 获取iOS平台的任务列表
        let currentTasks = config.currentPlatformTasks
        
        for task in currentTasks {
            let taskType = task.currentTaskId
            let adSlots = task.currentAdSlotIds
            
            adSlotCache[taskType] = adSlots
            
            Logger.adSlot("缓存任务类型 \(taskType)(\(task.currentTaskName)) 的广告位: \(adSlots)")
        }
        
        // 输出缓存总结
        let totalSlots = adSlotCache.values.reduce(0) { $0 + $1.count }
        Logger.success("广告位缓存完成: 共 \(adSlotCache.count) 种任务类型，总计 \(totalSlots) 个广告位", category: .adSlot)
    }
    
    /// 检查缓存是否有效
    private func isCacheValid() -> Bool {
        guard let lastUpdate = lastUpdateTime else { return false }
        
        let timeInterval = Date().timeIntervalSince(lastUpdate)
        let hoursElapsed = timeInterval / 3600
        
        return hoursElapsed < Double(cacheValidityHours) && !adSlotCache.isEmpty
    }
    
    /// 加载本地缓存数据
    private func loadCachedData() {
        // 加载缓存的广告位数据
        if let data = userDefaults.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode([Int: [String]].self, from: data) {
            adSlotCache = cached
        }
        
        // 加载最后更新时间
        if let lastUpdate = userDefaults.object(forKey: lastUpdateKey) as? Date {
            lastUpdateTime = lastUpdate
        }
        
        Logger.info("加载本地缓存 - 广告位数量: \(adSlotCache.count), 最后更新: \(lastUpdateTime?.description ?? "无")", category: .adSlot)
    }
    
    /// 保存缓存数据到本地
    private func saveCacheData() {
        // 保存广告位缓存
        if let data = try? JSONEncoder().encode(adSlotCache) {
            userDefaults.set(data, forKey: cacheKey)
        }
        
        // 保存最后更新时间
        if let lastUpdate = lastUpdateTime {
            userDefaults.set(lastUpdate, forKey: lastUpdateKey)
        }
        
        userDefaults.synchronize()
        
        Logger.success("保存缓存数据完成", category: .adSlot)
    }
}

// MARK: - Convenience Methods

extension AdSlotManager {
    
    /// 每日任务广告位相关方法（顺序获取）
    func getCurrentDailyAdSlotId(currentViewCount: Int) -> String? {
        return getCurrentAdSlotId(for: .dailyTask, currentViewCount: currentViewCount)
    }
    
    func getNextDailyAdSlotId(currentViewCount: Int) -> String? {
        return getNextAdSlotId(for: .dailyTask, currentViewCount: currentViewCount)
    }
    
    /// 每日任务观看间隔
    func getDailyTaskWatchInterval() -> Int {
        return getWatchInterval(for: .dailyTask)
    }
    
    /// 刷刷赚任务广告位相关方法（顺序获取）
    func getCurrentSwipeAdSlotId(currentViewCount: Int) -> String? {
        return getCurrentAdSlotId(for: .swipeTask, currentViewCount: currentViewCount)
    }
    
    func getNextSwipeAdSlotId(currentViewCount: Int) -> String? {
        return getNextAdSlotId(for: .swipeTask, currentViewCount: currentViewCount)
    }
    
    /// 刷刷赚任务观看间隔
    func getSwipeTaskWatchInterval() -> Int {
        return getWatchInterval(for: .swipeTask)
    }
    
    /// 开屏广告位相关方法（随机获取）
    func getCurrentSplashAdSlotId() -> String? {
        return getCurrentAdSlotId(for: .splash)
    }
    
    /// Banner广告位相关方法（随机获取）
    func getCurrentBannerAdSlotId() -> String? {
        return getCurrentAdSlotId(for: .banner)
    }
    
    /// 信息流广告位相关方法（随机获取）
    func getCurrentFeedAdSlotId() -> String? {
        return getCurrentAdSlotId(for: .feed)
    }
    
    /// 获取指定任务类型的任务名称
    func getTaskName(for taskType: AdSlotTaskType) -> String {
        return taskType.displayName
    }
    
    /// 获取指定任务类型的任务名称（Int版本，兼容旧代码）
    func getTaskName(for taskType: Int) -> String {
        return AdSlotTaskType(rawValue: taskType)?.displayName ?? "未知任务(\(taskType))"
    }
    
    /// 获取所有支持的任务类型
    func getAllSupportedTaskTypes() -> [AdSlotTaskType] {
        return AdSlotTaskType.allCases
    }
    
    /// 获取所有支持的任务类型（Int版本）
    func getAllSupportedTaskTypeIds() -> [Int] {
        return AdSlotTaskType.allCases.map { $0.rawValue }
    }
    
    /// 获取缓存的任务类型统计信息
    func getTaskTypesStatistics() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        for taskType in getAllSupportedTaskTypes() {
            let taskName = taskType.displayName
            let adSlots = getAllAdSlots(for: taskType)
            let hasSlots = hasAvailableAdSlots(for: taskType)
            let watchInterval = getWatchInterval(for: taskType)
            
            stats[taskName] = [
                "taskType": taskType.rawValue,
                "taskName": taskName,
                "adSlotCount": adSlots.count,
                "hasAvailableSlots": hasSlots,
                "adSlots": adSlots,
                "watchInterval": watchInterval,
                "requiresSequentialAccess": taskType.requiresSequentialAccess,
                "supportsPreloading": taskType.supportsPreloading
            ]
        }
        
        return stats
    }
}
