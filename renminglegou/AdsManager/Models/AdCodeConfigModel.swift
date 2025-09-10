//
//  AdPlatformModels.swift (Updated)
//  TaskCenter
//
//  Created by Developer on 2025/9/9.
//

import Foundation

/// 广告位任务类型枚举
enum AdSlotTaskType: Int, CaseIterable {
    case dailyTask = 1      // 每日任务
    case swipeTask = 2       // 刷刷赚
    case splash = 3         // 开屏
    case banner = 4         // Banner
    case feed = 5           // 信息流
    
    var displayName: String {
        switch self {
        case .dailyTask: return "每日任务"
        case .swipeTask: return "刷刷赚"
        case .splash: return "开屏"
        case .banner: return "Banner"
        case .feed: return "信息流"
        }
    }
    
    var description: String {
        switch self {
        case .dailyTask: return "完成每日广告观看任务"
        case .swipeTask: return "通过刷视频获得奖励"
        case .splash: return "应用启动时的开屏广告"
        case .banner: return "页面顶部或底部横幅广告"
        case .feed: return "信息流中的原生广告"
        }
    }
    
    /// 是否需要顺序获取广告位（vs 随机获取）
    var requiresSequentialAccess: Bool {
        switch self {
        case .dailyTask, .swipeTask:
            return true
        case .splash, .banner, .feed:
            return false
        }
    }
    
    /// 是否支持预加载下一个广告位
    var supportsPreloading: Bool {
        return requiresSequentialAccess
    }
}

// MARK: - 广告平台配置数据模型

/// 广告平台配置主数据
struct AdCodeConfig: Codable {
    let adPlatform: String?
    let platforms: [AdPlatform]?
}

/// 广告平台配置
struct AdPlatform: Codable {
    let platformType: String?
    let taskList: [AdSlotTask]?
}

/// 广告位任务配置
struct AdSlotTask: Codable {
    let taskName: String?
    let taskId: Int?
    let adSlotIds: [String]?
    let adWatchIntervalSec: Int?  // 新增：广告观看间隔（秒）
}

// MARK: - Extensions

extension AdCodeConfig {
    /// 获取广告平台名称
    var platformName: String {
        return adPlatform?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 获取指定类型的平台配置
    func platform(for type: String) -> AdPlatform? {
        return platforms?.first { $0.platformType?.lowercased() == type.lowercased() }
    }
    
    /// 获取Android平台配置
    var androidPlatform: AdPlatform? {
        return platform(for: "android")
    }
    
    /// 获取iOS平台配置
    var iosPlatform: AdPlatform? {
        return platform(for: "ios")
    }
    
    /// 获取iOS平台的任务列表
    var currentPlatformTasks: [AdSlotTask] {
        return iosPlatform?.taskList ?? []
    }
    
    /// 获取所有平台的任务总数
    var totalTaskCount: Int {
        return platforms?.reduce(0) { $0 + ($1.taskList?.count ?? 0) } ?? 0
    }
    
    /// 获取指定任务类型的广告位列表
    func getAdSlots(for taskType: Int) -> [String] {
        return currentPlatformTasks.first { $0.currentTaskId == taskType }?.currentAdSlotIds ?? []
    }
    
    /// 获取指定任务类型的观看间隔
    func getWatchInterval(for taskType: Int) -> Int {
        return currentPlatformTasks.first { $0.currentTaskId == taskType }?.currentWatchInterval ?? 0
    }
    
    /// 获取任务名称
    func getTaskName(for taskType: Int) -> String {
        return currentPlatformTasks.first { $0.currentTaskId == taskType }?.currentTaskName ?? "未知任务"
    }
    
    /// 打印广告位配置信息（用于调试）
    func debugDescription() -> String {
        var description = """
        广告平台: \(platformName)
        支持平台数量: \(platforms?.count ?? 0)
        iOS平台任务数量: \(iosPlatform?.taskCount ?? 0)
        
        """
        
        // 只显示iOS平台的配置
        if let iosPlatform = iosPlatform, let taskList = iosPlatform.taskList {
            description += "iOS平台配置:\n"
            for task in taskList {
                description += """
                  - \(task.currentTaskName) (ID: \(task.currentTaskId))
                    广告位数量: \(task.adSlotCount)
                    观看间隔: \(task.currentWatchInterval)秒
                    广告位: \(task.currentAdSlotIds.joined(separator: ", "))
                
                """
            }
        } else {
            description += "⚠️ 未找到iOS平台配置\n"
        }
        
        return description
    }
}

extension AdPlatform {
    /// 获取平台类型
    var currentPlatformType: String {
        return platformType?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 是否为Android平台
    var isAndroid: Bool {
        return currentPlatformType.lowercased() == "android"
    }
    
    /// 是否为iOS平台
    var isIOS: Bool {
        return currentPlatformType.lowercased() == "ios"
    }
    
    /// 获取任务数量
    var taskCount: Int {
        return taskList?.count ?? 0
    }
    
    /// 根据任务ID获取特定任务
    func task(withId taskId: Int) -> AdSlotTask? {
        return taskList?.first { $0.currentTaskId == taskId }
    }
    
    /// 根据任务名称获取特定任务
    func task(withName taskName: String) -> AdSlotTask? {
        return taskList?.first { $0.currentTaskName.lowercased() == taskName.lowercased() }
    }
    
    /// 获取所有广告位ID
    var allAdSlotIds: [String] {
        return taskList?.flatMap { $0.currentAdSlotIds } ?? []
    }
}

extension AdSlotTask {
    
    /// 获取任务名称
    var currentTaskName: String {
        return taskName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 获取任务ID
    var currentTaskId: Int {
        return taskId ?? 0
    }
    
    /// 获取广告位ID列表
    var currentAdSlotIds: [String] {
        return adSlotIds?.compactMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } ?? []
    }
    
    /// 获取广告观看间隔（秒）
    var currentWatchInterval: Int {
        return adWatchIntervalSec ?? 0
    }
    
    /// 获取任务类型
    var taskType: AdSlotTaskType? {
        return AdSlotTaskType(rawValue: currentTaskId)
    }
    
    /// 获取任务类型显示名称
    var taskTypeDisplayName: String {
        return taskType?.displayName ?? currentTaskName
    }
    
    /// 获取任务描述
    var taskTypeDescription: String {
        return taskType?.description ?? "广告任务"
    }
    
    /// 获取广告位数量
    var adSlotCount: Int {
        return currentAdSlotIds.count
    }
    
    /// 是否有有效的广告位
    var hasValidAdSlots: Bool {
        return adSlotCount > 0
    }
    
    /// 是否为有效任务
    var isValidTask: Bool {
        return currentTaskId > 0 && !currentTaskName.isEmpty && hasValidAdSlots
    }
    
    /// 获取主要广告位ID（第一个）
    var primaryAdSlotId: String? {
        return currentAdSlotIds.first
    }
    
    /// 获取备用广告位ID列表（除第一个外的其他）
    var backupAdSlotIds: [String] {
        return Array(currentAdSlotIds.dropFirst())
    }
    
    /// 是否需要顺序获取广告位
    var requiresSequentialAccess: Bool {
        return taskType?.requiresSequentialAccess ?? false
    }
    
    /// 是否支持预加载
    var supportsPreloading: Bool {
        return taskType?.supportsPreloading ?? false
    }
}
