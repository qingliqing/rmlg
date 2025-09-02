//
//  H5MessageHandler+Extensions.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import UIKit
import SwiftUI

extension H5MessageHandler {
    
    // MARK: - 处理方法实现
    static func handleLogin(_ body: Any) {
        let token = DataUtil.stringOf(body, defaultValue: "")
        UserModel.shared.updateToken(token)
        print("用户登录，Token: \(token)")
    }
    
    static func handleLogout() {
        UserModel.shared.logout()
        print("用户登出")
    }
    
    static func handleOpenUnionPay(_ body: Any, selfVC: UIViewController?) {
        let token = DataUtil.stringOf(body, defaultValue: "")
        showShareView(token: token, title: "", description: "")
    }
    
    static func handleOpenSkit(selfVC: UIViewController?) {
        openPlayletPage(from: selfVC)
    }
    
    static func handleOpenVideo(selfVC: UIViewController?) {
        openShortVideoPage(from: selfVC)
    }
    
    static func handleOpenTaskCenter(_ body: Any, selfVC: UIViewController?) {
        let token = DataUtil.stringOf(body, defaultValue: "")
        UserModel.shared.updateToken(token)
        
        let taskCenterView = TaskCenterView()
        let hostingController = UIHostingController(rootView: taskCenterView)
        selfVC?.navigationController?.pushViewController(hostingController, animated: true)
    }
    
    static func handleOpenAiSports(_ body: Any, selfVC: UIViewController?) {
        guard let dict = parseJSON(body) else { return }
        
        let token = DataUtil.stringOf(dict["token"], defaultValue: "")
        let path = DataUtil.stringOf(dict["path"], defaultValue: "")
        let title = DataUtil.stringOf(dict["title"], defaultValue: "")
        let type = DataUtil.stringOf(dict["type"], defaultValue: "")
        
        UserModel.shared.updateToken(token)
        openAiSportsPage(title: title, type: type, path: path, from: selfVC)
    }
    
    static func handleOpenChatPage(_ body: Any, selfVC: UIViewController?) {
        let token = DataUtil.stringOf(body, defaultValue: "")
        UserModel.shared.updateToken(token)
        
        let chatView = ChatView()
        let hostingController = UIHostingController(rootView: chatView)
        selfVC?.navigationController?.pushViewController(hostingController, animated: true)
    }
    
    static func handleOpenCustomerPage(_ body: Any, selfVC: UIViewController?) {
        guard let dict = parseJSON(body) else { return }
        
        let title = DataUtil.stringOf(dict["title"], defaultValue: "")
        let url = DataUtil.stringOf(dict["url"], defaultValue: "")
        
        if let webURL = URL(string: url) {
            let webView = WebViewPage(url: webURL, defaultTitle: title)
            let hostingController = UIHostingController(rootView: webView)
            selfVC?.navigationController?.pushViewController(hostingController, animated: true)
        }
    }
    
    static func handleCertificationSuccess(selfVC: UIViewController?) {
        selfVC?.navigationController?.popViewController(animated: true)
    }
    
    static func handleFinishPage(selfVC: UIViewController?) {
        selfVC?.navigationController?.popViewController(animated: true)
    }
    
    static func handleJumpToAppStore(_ body: Any) {
        let urlString = DataUtil.stringOf(body, defaultValue: "")
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    static func handleGetUserId(_ body: Any) {
        let userId = DataUtil.stringOf(body, defaultValue: "")
        UserModel.shared.updateUserid(userId)
    }
    
    static func handleShareWx(_ body: Any, selfVC: UIViewController?) {
        guard let dict = parseJSON(body) else { return }
        
        let url = DataUtil.stringOf(dict["url"], defaultValue: "")
        let title = DataUtil.stringOf(dict["title"], defaultValue: "")
        let description = DataUtil.stringOf(dict["des"], defaultValue: "")
        
        showShareView(token: url, title: title, description: description)
    }
    
    static func handleOpenAiMatch(_ body: Any, selfVC: UIViewController?) {
        guard let dict = parseJSON(body) else { return }
        
        let matchId = DataUtil.stringOf(dict["matchId"], defaultValue: "")
        let sportId = DataUtil.stringOf(dict["aiSportId"], defaultValue: "")
        let sportTimeMinute = DataUtil.stringOf(dict["sportTimeMinute"], defaultValue: "")
        let title = DataUtil.stringOf(dict["aiSportTitle"], defaultValue: "")
        
        startAiMatch(matchId: matchId, sportId: sportId, title: title, timeMinute: sportTimeMinute, from: selfVC)
    }
    
    // MARK: - 私有辅助方法
    private static func parseJSON(_ body: Any) -> [String: Any]? {
        guard let jsonString = body as? String,
              let jsonData = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            return nil
        }
        return dict
    }
    
    private static func showShareView(token: String, title: String, description: String) {
        print("显示分享视图: \(token), \(title), \(description)")
        // 实现分享视图显示逻辑
    }
    
    private static func openPlayletPage(from viewController: UIViewController?) {
        print("打开短剧页面")
        // 实现短剧页面打开逻辑
    }
    
    private static func openShortVideoPage(from viewController: UIViewController?) {
        print("打开短视频页面")
        // 实现短视频页面打开逻辑
    }
    
    private static func openAiSportsPage(title: String, type: String, path: String, from viewController: UIViewController?) {
        print("打开 AI 运动页面: \(title), 类型: \(type)")
        // 实现 AI 运动页面打开逻辑
    }
    
    private static func startAiMatch(matchId: String, sportId: String, title: String, timeMinute: String, from viewController: UIViewController?) {
        print("开始 AI 比赛: \(matchId), 运动: \(title)")
        // 实现 AI 比赛开始逻辑
    }
}
