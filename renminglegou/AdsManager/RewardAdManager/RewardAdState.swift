//
//  RewardAdState.swift
//  renminglegou
//
//  Created by abc on 2025/8/30.
//

import BUAdSDK

// MARK: - 广告状态枚举
enum RewardAdState {
    case initial                    // 初始状态
    case loading                    // 加载中
    case loaded                     // 加载成功
    case loadFailed                 // 加载失败
    case videoDownloaded           // 视频素材下载完成
    case showing                    // 正在展示
    case showFailed                // 展示失败
    case clicked                    // 被点击
    case skipped                    // 被跳过
    case playFinished              // 播放完成
    case playFailed                // 播放失败
    case rewardSuccess             // 奖励发放成功
    case rewardFailed              // 奖励发放失败
    case closed                     // 已关闭
}

// MARK: - 广告事件枚举（对外暴露）
enum RewardAdEvent {
    // 加载相关
    case loadStarted
    case loadSuccess
    case loadFailed(Error)
    case videoDownloaded
    
    // 展示相关
    case showStarted
    case showSuccess
    case showFailed(Error)
    
    // 交互相关
    case clicked
    case skipped
    
    // 播放相关
    case playFinished
    case playFailed(Error)
    
    // 奖励相关
    case rewardSuccess(verified: Bool)
    case rewardFailed(Error?)
    
    // 生命周期
    case closed
    
    // 便捷属性
    var isSuccess: Bool {
        switch self {
        case .loadSuccess, .showSuccess, .playFinished, .rewardSuccess, .videoDownloaded:
            return true
        default:
            return false
        }
    }
    
    var isError: Bool {
        switch self {
        case .loadFailed, .showFailed, .playFailed, .rewardFailed:
            return true
        default:
            return false
        }
    }
    
    var error: Error? {
        switch self {
        case .loadFailed(let error), .showFailed(let error), .playFailed(let error):
            return error
        case .rewardFailed(let error):
            return error
        default:
            return nil
        }
    }
    
    var description: String {
        switch self {
        case .loadStarted: return "开始加载"
        case .loadSuccess: return "加载成功"
        case .loadFailed(let error): return "加载失败: \(error.localizedDescription)"
        case .videoDownloaded: return "视频下载完成"
        case .showStarted: return "开始展示"
        case .showSuccess: return "展示成功"
        case .showFailed(let error): return "展示失败: \(error.localizedDescription)"
        case .clicked: return "广告被点击"
        case .skipped: return "广告被跳过"
        case .playFinished: return "播放完成"
        case .playFailed(let error): return "播放失败: \(error.localizedDescription)"
        case .rewardSuccess(let verified): return "奖励发放成功(验证: \(verified))"
        case .rewardFailed(let error): return "奖励发放失败: \(error?.localizedDescription ?? "未知错误")"
        case .closed: return "广告关闭"
        }
    }
}
