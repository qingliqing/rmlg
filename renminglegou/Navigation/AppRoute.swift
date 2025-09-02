// AppRoute.swift
// renminglegou
// 2025/9/2

import Foundation
import SwiftUI

// MARK: - 路由定义（扩展支持参数与模态）
enum AppRoute: Hashable {
    case splash
    case webView(url: URL, title: String = "", showBackButton: Bool = true)
    case taskCenter(params: [String: AnyHashable]? = nil)
    
    // 保留原来的标识（方便调试/打印/日志）
    var rawValue: String {
        switch self {
        case .splash: return "splash"
        case .webView: return "webView"
        case .taskCenter: return "taskCenter"
        }
    }
    
    // 页面标题
    var title: String {
        switch self {
        case .splash: return "启动页"
        case .webView(_, let title, _): return title
        case .taskCenter: return "任务中心"
        }
    }
    
    // 判断是否是模态展示（可以扩展）
    var isModal: Bool {
        switch self {
        case .webView, .taskCenter:
            return true
        default:
            return false
        }
    }
}
