//
//  AdTaskService.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation

// MARK: - 广告任务服务类
class TaskCenterService {
    private let networkManager = NetworkManager.shared
    
    // MARK: - 刷刷赚相关接口
    
    /// 发放积分
    func grantPoints(completion: @escaping (Result<Empty, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.grantPoints,
            responseType: Empty.self,
            completion: completion
        )
    }
    
    /// 获取广告奖励配置列表
    func getRewardConfigs(completion: @escaping (Result<[AdRewardConfig], NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getRewardConfigs,
            responseType: [AdRewardConfig].self,
            completion: completion
        )
    }
    
    /// 获取用户广告记录数量
    func getAdRecords(completion: @escaping (Result<AdRecord, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getAdRecords,
            responseType: AdRecord.self,
            completion: completion
        )
    }
    
    /// 获取用户看广告获取最大的积分
    func getMaxPoints(completion: @escaping (Result<AdPoints, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getMaxPoints,
            responseType: AdPoints.self,
            completion: completion
        )
    }
    
    /// 获取用户看当前广告获取的积分
    func getCurrentPoints(completion: @escaping (Result<AdPoints, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getCurrentPoints,
            responseType: AdPoints.self,
            completion: completion
        )
    }
    
    /// 获取广告配置
    func getAdConfig(completion: @escaping (Result<AdConfig, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getAdConfig,
            responseType: AdConfig.self,
            completion: completion
        )
    }
    
    // MARK: - 每日广告任务相关接口
    
    /// 用户领取广告任务
    func receiveTask(taskType: Int, completion: @escaping (Result<Empty, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.receiveTask(taskType: taskType),
            responseType: Empty.self,
            completion: completion
        )
    }
    
    /// 用户完成一次广告观看
    func completeView(
        taskType: Int,
        adFinishFlag: String? = nil,
        completion: @escaping (Result<Empty, NetworkError>) -> Void
    ) {
        networkManager.request(
            endpoint: AdTaskAPI.completeView(taskType: taskType, adFinishFlag: adFinishFlag),
            responseType: Empty.self,
            completion: completion
        )
    }
    
    /// 获取用户当天已观看广告数量
    func getTodayCount(taskType: Int, completion: @escaping (Result<TodayAdCount, NetworkError>) -> Void) {
        networkManager.request(
            endpoint: AdTaskAPI.getTodayCount(taskType: taskType),
            responseType: TodayAdCount.self,
            completion: completion
        )
    }
    
    // MARK: - Async/Await 版本 (iOS 13.0+)
    
    @available(iOS 13.0, *)
    func grantPoints() async throws -> Empty {
        return try await networkManager.request(
            endpoint: AdTaskAPI.grantPoints,
            responseType: Empty.self
        )
    }
    
    @available(iOS 13.0, *)
    func getRewardConfigs() async throws -> [AdRewardConfig] {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getRewardConfigs,
            responseType: [AdRewardConfig].self
        )
    }
    
    @available(iOS 13.0, *)
    func getAdRecords() async throws -> AdRecord {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getAdRecords,
            responseType: AdRecord.self
        )
    }
    
    @available(iOS 13.0, *)
    func getMaxPoints() async throws -> AdPoints {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getMaxPoints,
            responseType: AdPoints.self
        )
    }
    
    @available(iOS 13.0, *)
    func getCurrentPoints() async throws -> AdPoints {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getCurrentPoints,
            responseType: AdPoints.self
        )
    }
    
    @available(iOS 13.0, *)
    func getAdConfig() async throws -> AdConfig {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getAdConfig,
            responseType: AdConfig.self
        )
    }
    
    @available(iOS 13.0, *)
    func receiveTask(taskType: Int) async throws -> Empty {
        return try await networkManager.request(
            endpoint: AdTaskAPI.receiveTask(taskType: taskType),
            responseType: Empty.self
        )
    }
    
    @available(iOS 13.0, *)
    func completeView(taskType: Int, adFinishFlag: String? = nil) async throws -> Empty {
        return try await networkManager.request(
            endpoint: AdTaskAPI.completeView(taskType: taskType, adFinishFlag: adFinishFlag),
            responseType: Empty.self
        )
    }
    
    @available(iOS 13.0, *)
    func getTodayCount(taskType: Int) async throws -> TodayAdCount {
        return try await networkManager.request(
            endpoint: AdTaskAPI.getTodayCount(taskType: taskType),
            responseType: TodayAdCount.self
        )
    }
}
