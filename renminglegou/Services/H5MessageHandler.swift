//
//  H5MessageHandler.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import WebKit
import UIKit

class H5MessageHandler: NSObject {
    
    static func receiveScriptMessage(_ message: WKScriptMessage, selfVC: UIViewController?, webView: WKWebView?, navigationManager: NavigationManager? = nil) {
        
        switch message.name {
        case "onLoginEvent":
            handleLogin(message.body)
        case "onLogoutEvent":
            handleLogout()
        case "shareAiVideo":
            handleShareAiVideo(message.body, selfVC: selfVC)
        case "openSkit":
            handleOpenSkit(selfVC: selfVC)
        case "openVidel":
            handleOpenVideo(selfVC: selfVC)
        case "openTaskCenter":
            handleOpenTaskCenter(message.body, navigationManager: navigationManager)
        case "onCertificationSuccess":
            handleCertificationSuccess(selfVC: selfVC)
        case "onFinishPage":
            handleFinishPage(selfVC: selfVC)
        case "jumpToAppStore":
            handleJumpToAppStore(message.body)
        case "getUserId":
            handleGetUserId(message.body)
        case "shareWx":
            handleShareWx(message.body, selfVC: selfVC)
        default:
            print("未处理的消息: \(message.name)")
        }
    }
    
    // 修改任务中心处理方法
    private static func handleOpenTaskCenter(_ body: Any, navigationManager: NavigationManager?) {
        guard let navigationManager = navigationManager else {
            print("NavigationManager 不可用")
            return
        }
        
        // 解析参数
        var params: [String: Any]? = nil
        if let bodyDict = body as? [String: Any] {
            params = bodyDict
        }
        
        // 使用 SwiftUI 导航
        DispatchQueue.main.async {
            navigationManager.navigateTo(.taskCenter(params: params))
        }
    }
    
    
    static func h5CallJSReturnValue(prompt: String, completionHandler: @escaping (String?) -> Void) {
        switch prompt {
        case "getCacheSize":
            let cacheSize = CacheManager.getCacheSize()
            completionHandler(cacheSize)
        case "cleanCache":
            CacheManager.cleanCache()
            completionHandler("true")
        default:
            completionHandler("")
        }
    }
}
