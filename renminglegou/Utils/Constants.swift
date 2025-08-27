//
//  Constants.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation
import UIKit

// UserDefaults Keys
struct UserDefaultsKeys {
    static let userToken = "user_token"
    static let userId = "user_id"
    static let unreadMessageCount = "unread_message_count"
    static let unlockWatchAd = "unlockWatchAd"
}

struct DeviceConsts {
    static var totalHeight: CGFloat {
        return statusBarHeight + navBarHeight
    }
    
    static var statusBarHeight: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        
        let statusBarHeight = window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        return statusBarHeight
    }
    
    static var navBarHeight: CGFloat {
        return 44
    }
    
}

// H5 消息名称
struct H5Messages {
    static let onLoginEvent = "onLoginEvent"
    static let onLogoutEvent = "onLogoutEvent"
    static let shareAiVideo = "shareAiVideo"
    static let openSkit = "openSkit"
    static let openVidel = "openVidel"
    static let openTaskCenter = "openTaskCenter"
    static let openAiSports = "openAiSports"
    static let openChatPage = "openChatPage"
    static let openCustomerPage = "openCustomerPage"
    static let onCertificationSuccess = "onCertificationSuccess"
    static let onFinishPage = "onFinishPage"
    static let jumpToAppStore = "jumpToAppStore"
    static let getUserId = "getUserId"
    static let shareWx = "shareWx"
    static let openAiMatch = "openAiMatch"
}
