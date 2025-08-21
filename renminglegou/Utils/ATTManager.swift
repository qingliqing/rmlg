//
//  ATTManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/21.
//

import SwiftUI
import AppTrackingTransparency
import AdSupport

class ATTManager: ObservableObject {
    @Published var trackingStatus: ATTrackingManager.AuthorizationStatus = .notDetermined
    @Published var idfa: String = ""
    
    static let shared = ATTManager()
    
    private init() {
        
    }
    
    /// 请求跟踪授权
    func requestTrackingAuthorization() {
        // 检查是否可以请求授权
        guard canRequestAuthorization else {
            print("已经请求过授权，当前状态：\(ATTrackingManager.trackingAuthorizationStatus.description)")
            updateTrackingStatus()
            return
        }
        
        ATTrackingManager.requestTrackingAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.updateTrackingStatus()
                
                switch status {
                case .authorized:
                    print("用户授权了跟踪")
                    self?.getIDFA()
                case .denied:
                    print("用户拒绝了跟踪")
                case .restricted:
                    print("跟踪被限制")
                case .notDetermined:
                    print("用户尚未决定")
                @unknown default:
                    print("未知状态")
                }
            }
        }
    }
    
    /// 更新跟踪状态
    private func updateTrackingStatus() {
        trackingStatus = ATTrackingManager.trackingAuthorizationStatus
        getIDFA()
    }
    
    /// 获取 IDFA
    private func getIDFA() {
        if ATTrackingManager.trackingAuthorizationStatus == .authorized {
            idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        } else {
            idfa = "00000000-0000-0000-0000-000000000000"
        }
        
        print("当前 IDFA: \(idfa)")
    }
    
    /// 检查是否可以请求授权
    var canRequestAuthorization: Bool {
        return ATTrackingManager.trackingAuthorizationStatus == .notDetermined
    }
    
    /// 是否已授权
    var isAuthorized: Bool {
        return ATTrackingManager.trackingAuthorizationStatus == .authorized
    }
}

// MARK: - ATTrackingManager.AuthorizationStatus 扩展
extension ATTrackingManager.AuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "未确定"
        case .restricted:
            return "受限制"
        case .denied:
            return "已拒绝"
        case .authorized:
            return "已授权"
        @unknown default:
            return "未知"
        }
    }
}
