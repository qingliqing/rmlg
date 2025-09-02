//
//  AppRoute.swift
//  renminglegou
//
//  Created by abc on 2025/9/2.
//

// MARK: - 路由定义（扩展支持模态）
enum AppRoute: String, CaseIterable, Equatable {
    case splash = "splash"
    case main = "main"
    case webView = "webView"
    case taskCenter = "taskCenter"
    
    var title: String {
        switch self {
        case .splash: return "启动页"
        case .main: return "主页"
        case .webView: return "网页"
        case .taskCenter: return "任务中心"
        }
    }
}
