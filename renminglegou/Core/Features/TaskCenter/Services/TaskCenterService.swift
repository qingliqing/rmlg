//
//  TaskCenterService.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation

enum TaskCenterError: Error {
    case alipayNotVerified // 10023
    case alreadyPaid // 50010
    case networkError(String)
    case unknownError
    
    var localizedDescription: String {
        switch self {
        case .alipayNotVerified:
            return "10023"
        case .alreadyPaid:
            return "50010"
        case .networkError(let message):
            return message
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}

class TaskCenterService: ObservableObject {
    
    // MARK: - Constants
    private let baseWebUrl = "https://your-base-url.com"
    private let normalMvIds = [
        "normal_MvFirst",
        "normal_MvSecond",
        "normal_Third",
        "normal_Fourth",
        "normal_Fifth"
    ]
    
    // MARK: - Public Methods
    
    /// Get task center information
    func getTaskCenterInfo() async throws -> TaskCenterInfoModel {
        // Simulate network request
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Mock data - replace with actual API call
        return TaskCenterInfoModel(
            taskId: "task_001",
            userId: "user_123",
            adSkipTime: 30,
            advViewNum: 2,
            isCompleted: false,
            title: "每日签到任务",
            description: "完成每日签到获得金币奖励",
            reward: 100
        )
    }
    
    /// Get activity list
    func getActivityList() async throws -> [ActivityModel] {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Mock data - replace with actual API call
        return [
            ActivityModel(acId: "act_001", name: "限时活动1", acUrl: "/activity1", urlType: 1, imageUrl: ""),
            ActivityModel(acId: "act_002", name: "限时活动2", acUrl: "https://external.com/activity2", urlType: 2, imageUrl: ""),
            ActivityModel(acId: "act_003", name: "限时活动3", acUrl: "/activity3", urlType: 1, imageUrl: "")
        ]
    }
    
    /// Get app settings
    func getSettings() async throws -> [String: Int] {
        try await Task.sleep(nanoseconds: 300_000_000)
        
        // Mock data - replace with actual API call
        return [
            "adIntervalTime": 60,
            "adOpenBV": 1
        ]
    }
    
    /// Finish task and get reward
    func finishTask(taskId: String, captchaValidate: String) async throws {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate different error scenarios
        let random = Int.random(in: 1...10)
        if random <= 2 {
            throw TaskCenterError.alipayNotVerified
        }
        
        print("Task completed successfully: \(taskId)")
    }
    
    /// Finish advertisement watching
    func finishAdvertisement(taskId: String, captchaValidate: String, uuid: String = "") async throws {
        try await Task.sleep(nanoseconds: 800_000_000)
        
        print("Advertisement finished: \(taskId)")
    }
    
    /// Show verification code
    func showVerificationCode(captchaId: String, timeout: Int = 10, hideCloseButton: Bool = false) async throws -> String {
        try await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Simulate verification code validation
        let success = Bool.random()
        if success {
            return "mock_validation_code_\(UUID().uuidString.prefix(8))"
        } else {
            throw TaskCenterError.networkError("验证码验证失败")
        }
    }
    
    /// Get verification cost
    func getVerificationCost() async throws -> String {
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Simulate different scenarios
        let random = Int.random(in: 1...10)
        if random <= 2 {
            throw TaskCenterError.alreadyPaid
        }
        
        return "2.00"
    }
    
    /// Create fee order
    func createFeeOrder(orderAmount: String) async throws -> String {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        let orderId = "order_\(UUID().uuidString.prefix(10))"
        print("Fee order created: \(orderId) with amount: \(orderAmount)")
        return orderId
    }
    
    /// Record activity click
    func recordActivityClick(activityId: String) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        print("Activity click recorded for: \(activityId)")
    }
    
    /// Show advertisement by view number
    func showAdvertisement(advViewNum: Int) async throws {
        let adIndex = min(advViewNum, normalMvIds.count - 1)
        let adId = normalMvIds[adIndex]
        
        // Simulate advertisement loading and playing
        try await Task.sleep(nanoseconds: 3_000_000_000)
        print("Advertisement played: \(adId)")
    }
    
    /// Get activity URL based on type
    func getActivityUrl(activity: ActivityModel) -> String {
        if activity.urlType == 1 {
            return "\(baseWebUrl)/#\(activity.acUrl)?jumpType=1"
        } else {
            return activity.acUrl
        }
    }
    
    /// Get Alipay verification URL
    func getAlipayVerificationUrl() -> String {
        return "\(baseWebUrl)/#/pages/faceId/faceId?from=app"
    }
}
