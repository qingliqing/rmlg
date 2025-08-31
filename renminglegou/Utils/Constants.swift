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
    
    // MARK: - 导航栏和状态栏
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
    
    // MARK: - 屏幕尺寸
    static var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    static var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    static var screenBounds: CGRect {
        return UIScreen.main.bounds
    }
    
    static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    // MARK: - 安全区域
    static var safeAreaInsets: UIEdgeInsets {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first
        return window?.safeAreaInsets ?? UIEdgeInsets.zero
    }
    
    static var safeAreaTop: CGFloat {
        return safeAreaInsets.top
    }
    
    static var safeAreaBottom: CGFloat {
        return safeAreaInsets.bottom
    }
    
    static var safeAreaLeft: CGFloat {
        return safeAreaInsets.left
    }
    
    static var safeAreaRight: CGFloat {
        return safeAreaInsets.right
    }
    
    // MARK: - 可用区域（去除状态栏和导航栏）
    static var availableHeight: CGFloat {
        return screenHeight - totalHeight - safeAreaBottom
    }
    
    static var availableWidth: CGFloat {
        return screenWidth - safeAreaLeft - safeAreaRight
    }
    
    // MARK: - 设备类型判断
    static var isIPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isIPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isSmallScreen: Bool {
        return screenWidth <= 375 // iPhone SE, iPhone 12 mini等
    }
    
    static var isMediumScreen: Bool {
        return screenWidth > 375 && screenWidth <= 414 // iPhone 12, iPhone 13等
    }
    
    static var isLargeScreen: Bool {
        return screenWidth > 414 // iPhone 12 Pro Max, iPhone 13 Pro Max等
    }
    
    // MARK: - 常用间距
    static var paddingXS: CGFloat { return 4 }
    static var paddingS: CGFloat { return 8 }
    static var paddingM: CGFloat { return 12 }
    static var paddingL: CGFloat { return 16 }
    static var paddingXL: CGFloat { return 20 }
    static var paddingXXL: CGFloat { return 24 }
    static var paddingXXXL: CGFloat { return 32 }
    
    // 水平默认间距
    static var horizontalPadding: CGFloat {
        return isIPad ? paddingXXL : paddingL
    }
    
    // 垂直默认间距
    static var verticalPadding: CGFloat {
        return paddingL
    }
    
    // MARK: - 常用UI元素尺寸
    static var buttonHeight: CGFloat {
        return isSmallScreen ? 44 : 48
    }
    
    static var inputFieldHeight: CGFloat {
        return isSmallScreen ? 44 : 48
    }
    
    static var toolbarHeight: CGFloat {
        return 56
    }
    
    static var tabBarHeight: CGFloat {
        return 49 + safeAreaBottom
    }
    
    static var cardCornerRadius: CGFloat {
        return 12
    }
    
    static var buttonCornerRadius: CGFloat {
        return 8
    }
    
    // MARK: - 响应式宽度
    static func responsiveWidth(factor: CGFloat = 1.0) -> CGFloat {
        return screenWidth * factor
    }
    
    static func responsiveHeight(factor: CGFloat = 1.0) -> CGFloat {
        return screenHeight * factor
    }
    
    // MARK: - 适配不同屏幕的数值
    static func adaptiveValue(small: CGFloat, medium: CGFloat, large: CGFloat) -> CGFloat {
        if isSmallScreen {
            return small
        } else if isMediumScreen {
            return medium
        } else {
            return large
        }
    }
    
    // MARK: - 调试信息
    static func printDeviceInfo() {
        print("📱 设备信息:")
        print("   屏幕尺寸: \(screenWidth) x \(screenHeight)")
        print("   安全区域: top=\(safeAreaTop), bottom=\(safeAreaBottom)")
        print("   状态栏高度: \(statusBarHeight)")
        print("   导航栏高度: \(navBarHeight)")
        print("   可用区域: \(availableWidth) x \(availableHeight)")
        print("   设备类型: \(isIPhone ? "iPhone" : "iPad")")
        print("   屏幕类型: \(isSmallScreen ? "小屏" : isMediumScreen ? "中屏" : "大屏")")
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
