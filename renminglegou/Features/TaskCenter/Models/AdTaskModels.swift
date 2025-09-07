//
//  AdTaskModels.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation

// MARK: - 广告任务相关数据模型

/// 广告奖励配置
struct AdRewardConfig: Codable {
    let id: Int?
    let points: Int?
    let enabled: Bool?
    let rewardDescription: String?
    let adCountStart: Int?
    let adCountEnd: Int?
}

/// 广告积分 - 根据API返回的是数字类型
struct AdPoints: Codable {
    let points: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try? container.decode(Int.self)
        self.points = value
    }
}

/// 广告配置 - 根据实际API结构
struct AdConfig: Codable {
    let tasks: [AdTask]?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.tasks = try container.decodeIfPresent([AdTask].self, forKey: .tasks)
    }
}

/// 广告任务配置
struct AdTask: Codable {
    let id: Int?
    let taskName: TaskText?
    let taskDescription: TaskDescription?
    let sortOrder: Int?
    let adTotalCount: String?
    let jumpLink: String?
    let status: Int?              // 状态码
    let statusMsg: String?        // 状态消息
}

/// 广告任务进度
struct AdTaskProgress: Codable {
    let id: Int?
    let userId: String?
    let taskType: Int?
    let adViewCount: Int?
    let isCompleted: Bool?
    let createTime: String?
    let updateTime: String?
}

/// 任务文本
struct TaskText: Codable {
    let text: String?
    let fontSize: Int?
}

/// 任务描述
struct TaskDescription: Codable {
    let level1: TaskText?
    let level2: TaskText?
    let level3: TaskText?
    let level4: TaskText?
}

// MARK: - Extensions

// 在 AdTask 结构体中添加
extension AdTask {
    /// 获取任务总数
    var totalAdCount: Int {
        guard let countString = adTotalCount?.trimmingCharacters(in: .whitespacesAndNewlines),
              !countString.isEmpty,
              let count = Int(countString) else { return 0 }
        return count
    }
    
    /// 获取任务类型
    var taskType: Int {
        return id ?? 0
    }
    
    /// 是否有跳转链接
    var hasJumpLink: Bool {
        return !(jumpLink?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }
    
    /// 获取状态码
    var taskStatus: Int {
        return status ?? 0
    }
    
    /// 获取状态消息
    var statusMessage: String {
        return statusMsg?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 是否有状态消息需要显示
    var hasStatusMessage: Bool {
        return !statusMessage.isEmpty
    }
}

// 在 AdTaskProgress 结构体中添加
extension AdTaskProgress {
    /// 获取当前观看次数
    var currentViewCount: Int {
        return adViewCount ?? 0
    }
    
    /// 获取任务类型ID
    var currentTaskType: Int {
        return taskType ?? 0
    }
    
    /// 获取用户ID
    var currentUserId: String {
        return userId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    /// 是否已完成
    var completed: Bool {
        return isCompleted ?? false
    }
    
    /// 格式化创建时间
    var formattedCreateTime: Date? {
        guard let createTime = createTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: createTime)
    }
    
    /// 格式化更新时间
    var formattedUpdateTime: Date? {
        guard let updateTime = updateTime else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: updateTime)
    }
}

// 在 TaskText 结构体中添加
extension TaskText {
    var displayText: String {
        return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    var displayFontSize: CGFloat {
        return CGFloat(fontSize ?? 16)
    }
}

// 在 TaskDescription 结构体中添加
extension TaskDescription {
    var primaryText: String {
        return level1?.displayText ?? ""
    }
}

