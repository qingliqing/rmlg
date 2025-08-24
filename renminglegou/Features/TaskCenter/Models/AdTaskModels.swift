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
    let rewardPoints: Int?
    let maxViewCount: Int?
    let taskType: Int?
}

/// 广告记录
struct AdRecord: Codable {
    let todayCount: Int?
    let totalCount: Int?
}

/// 广告积分
struct AdPoints: Codable {
    let points: Int?
}

/// 广告配置
struct AdConfig: Codable {
    let enabled: Bool?
    let adUnitId: String?
    let rewardPoints: Int?
}

/// 今日广告观看次数
struct TodayAdCount: Codable {
    let count: Int?
}
