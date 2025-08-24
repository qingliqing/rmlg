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

