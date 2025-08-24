//
//  NetworkApi.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 网络配置

/// 网络API配置
struct NetworkAPI {
    /// 主API基础URL
    static let baseURL = "https://api.hzyzzc.cn/"
    /// Web页面基础URL
    static let baseWebURL = "https://saas.hzyzzc.cn/app/"
    /// 请求超时时间（秒）
    static let timeout: TimeInterval = 30
}

// MARK: - 广告任务API端点

/// 广告任务相关的API端点枚举
enum AdTaskAPI {
    
    // MARK: - 刷刷赚相关接口
    
    /// 发放积分
    /// - Description: 用户观看广告后，调用此接口发放对应的积分奖励
    case grantPoints
    
    /// 获取广告奖励配置列表
    /// - Description: 获取不同类型广告的奖励配置信息，包括奖励金额、观看次数限制等
    case getRewardConfigs
    
    /// 获取用户广告记录数量
    /// - Description: 获取用户的广告观看历史记录统计信息
    case getAdRecords
    
    /// 获取用户看广告获取的最大积分
    /// - Description: 获取用户通过观看广告能够获得的最大积分数量限制
    case getMaxPoints
    
    /// 获取用户看当前广告获取的积分
    /// - Description: 获取用户当前观看广告可以获得的积分数量
    case getCurrentPoints
    
    /// 获取广告配置
    /// - Description: 获取广告系统的基础配置信息，如广告位设置、展示规则等
    case getAdConfig
    
    // MARK: - 每日广告任务相关接口
    
    /// 用户领取广告任务
    /// - Parameter taskType: 任务类型标识符
    /// - Description: 用户主动领取指定类型的广告任务，领取后才能开始观看广告获得奖励
    case receiveTask(taskType: Int)
    
    /// 用户完成一次广告观看
    /// - Parameters:
    ///   - taskType: 任务类型标识符
    ///   - adFinishFlag: 广告完成标识（可选），用于验证广告是否完整观看
    /// - Description: 记录用户完成一次广告观看的行为，用于统计和验证
    case completeView(taskType: Int, adFinishFlag: String?)
    
    /// 获取用户当天已观看广告数量
    /// - Parameter taskType: 任务类型标识符
    /// - Description: 查询用户在当天已经观看的指定类型广告的数量，用于判断是否达到每日上限
    case getTodayCount(taskType: Int)
}

// MARK: - AdTaskAPI 扩展实现

extension AdTaskAPI {
    
    /// API端点路径
    var path: String {
        switch self {
        // 刷刷赚相关路径
        case .grantPoints:
            return "customer/ad/grantPoints"
        case .getRewardConfigs:
            return "customer/ad/reward/configs"
        case .getAdRecords:
            return "customer/ad/records"
        case .getMaxPoints:
            return "customer/ad/max-points"
        case .getCurrentPoints:
            return "customer/ad/curr-points"
        case .getAdConfig:
            return "customer/ad/ad-config"
            
        // 每日广告任务相关路径
        case .receiveTask:
            return "customer/ad/task/receive"
        case .completeView:
            return "customer/ad/task/complete-view"
        case .getTodayCount:
            return "customer/ad/task/today-count"
        }
    }
    
    /// HTTP请求方法
    var method: HTTPMethod {
        switch self {
        // POST 请求：涉及数据提交和状态变更的操作
        case .grantPoints, .receiveTask, .completeView:
            return .post
            
        // GET 请求：数据查询操作
        case .getRewardConfigs, .getAdRecords, .getMaxPoints, .getCurrentPoints, .getAdConfig, .getTodayCount:
            return .get
        }
    }
    
    /// 请求参数
    var parameters: Parameters? {
        switch self {
        case .receiveTask(let taskType):
            // 领取任务时需要传递任务类型
            return ["taskType": taskType]
            
        case .completeView(let taskType, let adFinishFlag):
            // 完成观看时传递任务类型，可选传递完成标识
            var params: Parameters = ["taskType": taskType]
            if let flag = adFinishFlag {
                params["adFinishFlag"] = flag
            }
            return params
            
        case .getTodayCount(let taskType):
            // 查询当日观看数量时需要传递任务类型
            return ["taskType": taskType]
            
        default:
            // 其他接口无需参数
            return nil
        }
    }
}
