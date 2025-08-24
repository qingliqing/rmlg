//
//  NetworkApi.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 广告任务 API 端点

// API 相关
struct NetworkAPI {
    static let baseURL = "https://api.hzyzzc.cn/"
    static let baseWebURL = "https://saas.hzyzzc.cn/app/"
    
    static let timeout: TimeInterval = 30
}

enum AdTaskAPI {
    // 刷刷赚相关
    case grantPoints
    case getRewardConfigs
    case getAdRecords
    case getMaxPoints
    case getCurrentPoints
    case getAdConfig
    
    // 每日广告任务相关
    case receiveTask(taskType: Int)
    case completeView(taskType: Int, adFinishFlag: String?)
    case getTodayCount(taskType: Int)
}

extension AdTaskAPI: APIEndpoint {
    var path: String {
        switch self {
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
        case .receiveTask:
            return "customer/ad/task/receive"
        case .completeView:
            return "customer/ad/task/complete-view"
        case .getTodayCount:
            return "customer/ad/task/today-count"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .grantPoints, .receiveTask, .completeView:
            return .post
        case .getRewardConfigs, .getAdRecords, .getMaxPoints, .getCurrentPoints, .getAdConfig, .getTodayCount:
            return .get
        }
    }
    
    var parameters: Parameters? {
        switch self {
        case .receiveTask(let taskType):
            return ["taskType": taskType]
        case .completeView(let taskType, let adFinishFlag):
            var params: Parameters = ["taskType": taskType]
            if let flag = adFinishFlag {
                params["adFinishFlag"] = flag
            }
            return params
        case .getTodayCount(let taskType):
            return ["taskType": taskType]
        default:
            return nil
        }
    }
}
