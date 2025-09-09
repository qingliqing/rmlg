//
//  AdTaskService.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation

// MARK: - 广告任务服务类
class TaskCenterService {
    static let shared = TaskCenterService()
    private let networkManager = NetworkManager.shared
    
    private init() {}
    
    // MARK: - 刷刷赚相关接口
    
    /// 获取广告奖励配置列表
    func getRewardConfigs() async throws -> [AdRewardConfig] {
        let api = AdTaskAPI.getRewardConfigs
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: [AdRewardConfig].self
        )
    }
    
    /// 获取广告配置
    func getAdConfig() async throws -> AdConfig {
        let api = AdTaskAPI.getAdConfig
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: AdConfig.self
        )
    }
    
    // MARK: - 广告平台配置相关接口
    
    /// 获取所有广告位列表
    func getAdCodeList() async throws -> AdCodeConfig {
        let api = AdTaskAPI.getAdCodeList
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: AdCodeConfig.self
        )
    }
    
    // MARK: - 每日广告任务相关接口
    
    /// 用户领取广告任务
    /// - Parameter taskType: 任务类型
    func receiveTask(taskType: Int) async throws -> AdTaskProgress {
        let api = AdTaskAPI.receiveTask(taskType: taskType)
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: AdTaskProgress.self
        )
    }
    
    /// 获取用户当天已观看广告数量
    /// - Parameter taskType: 任务类型
    func getTodayCount(taskType: Int) async throws -> Int {
        let api = AdTaskAPI.getTodayCount(taskType: taskType)
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: Int.self
        )
    }
    
    // MARK: - 便捷方法
    
    /// 完整的观看广告流程
    /// - Parameters:
    ///   - taskType: 任务类型
    ///   - adFinishFlag: 广告完成标识
    /// - Returns: 是否成功完成流程
    func completeAdWatchFlow(taskType: Int, adFinishFlag: String? = nil) async throws -> Bool {
        do {
            // 先领取新任务
            _ = try await receiveTask(taskType: taskType)
            
            return true
        } catch {
            print("完成广告观看流程失败: \(error)")
            throw error
        }
    }
}

// MARK: - 便捷扩展（向后兼容的回调版本）
extension TaskCenterService {
    
    /// 获取广告奖励配置列表（回调版本）
    func getRewardConfigs(completion: @escaping (Result<[AdRewardConfig], NetworkError>) -> Void) {
        Task {
            do {
                let result = try await getRewardConfigs()
                await MainActor.run {
                    completion(.success(result))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error as? NetworkError ?? .networkError(error)))
                }
            }
        }
    }
    
    // 其他方法的回调版本可以按需添加...
}
