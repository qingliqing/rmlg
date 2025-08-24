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
    
    /// 发放积分
    func grantPoints() async throws -> Empty {
        let api = AdTaskAPI.grantPoints
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: Empty.self
        )
    }
    
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
    
    /// 获取用户广告记录数量
    func getAdRecords() async throws -> Int {
        let api = AdTaskAPI.getAdRecords
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: Int.self
        )
    }
    
    /// 获取用户看广告获取最大的积分
    func getMaxPoints() async throws -> AdPoints {
        let api = AdTaskAPI.getMaxPoints
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: AdPoints.self
        )
    }
    
    /// 获取用户看当前广告获取的积分
    func getCurrentPoints() async throws -> AdPoints {
        let api = AdTaskAPI.getCurrentPoints
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: AdPoints.self
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
    
    // MARK: - 每日广告任务相关接口
    
    /// 用户领取广告任务
    /// - Parameter taskType: 任务类型
    func receiveTask(taskType: Int) async throws -> Empty {
        let api = AdTaskAPI.receiveTask(taskType: taskType)
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: Empty.self
        )
    }
    
    /// 用户完成一次广告观看
    /// - Parameters:
    ///   - taskType: 任务类型
    ///   - adFinishFlag: 广告完成标识（可选）
    func completeView(taskType: Int, adFinishFlag: String? = nil) async throws -> Empty {
        let api = AdTaskAPI.completeView(taskType: taskType, adFinishFlag: adFinishFlag)
        return try await networkManager.request(
            path: api.path,
            method: api.method,
            parameters: api.parameters,
            responseType: Empty.self
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
            // 1. 先领取任务
            _ = try await receiveTask(taskType: taskType)
            
            // 2. 完成观看
            _ = try await completeView(taskType: taskType, adFinishFlag: adFinishFlag)
            
            // 3. 发放积分
            _ = try await grantPoints()
            
            return true
        } catch {
            print("完成广告观看流程失败: \(error)")
            throw error
        }
    }
    
    /// 获取完整的广告状态信息
    /// - Parameter taskType: 任务类型
    /// - Returns: 广告状态信息元组
    func getAdStatusInfo(taskType: Int) async throws -> (todayCount: Int, currentPoints: AdPoints, maxPoints: AdPoints) {
        async let todayCount = getTodayCount(taskType: taskType)
        async let currentPoints = getCurrentPoints()
        async let maxPoints = getMaxPoints()
        
        return try await (todayCount, currentPoints, maxPoints)
    }
}

// MARK: - 便捷扩展（向后兼容的回调版本）
extension TaskCenterService {
    
    /// 发放积分（回调版本）
    func grantPoints(completion: @escaping (Result<Empty, NetworkError>) -> Void) {
        Task {
            do {
                let result = try await grantPoints()
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
    
    /// 用户完成一次广告观看（回调版本）
    func completeView(taskType: Int, adFinishFlag: String? = nil, completion: @escaping (Result<Empty, NetworkError>) -> Void) {
        Task {
            do {
                let result = try await completeView(taskType: taskType, adFinishFlag: adFinishFlag)
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
