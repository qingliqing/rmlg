//
//  WebviewWrapper.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI
import WebKit

struct WebViewWrapper: UIViewRepresentable {
    let url: URL
    @Binding var pageTitle: String
    
    func makeUIView(context: Context) -> WKWebView {
        let userContentController = WKUserContentController()
        
        // 注入 Cookie（在注册消息处理器之前）
        injectCookies(to: userContentController, for: url.absoluteString)
        
        let messageHandlers = [
            "onLoginEvent", "onLogoutEvent", "shareAiVideo", "openSkit",
            "openVidel", "openTaskCenter", "openAiSports", "openChatPage",
            "openCustomerPage", "onCertificationSuccess", "onFinishPage",
            "jumpToAppStore", "getUserId", "shareWx", "openAiMatch"
        ]
        
        for handler in messageHandlers {
            userContentController.add(context.coordinator, name: handler)
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // 创建带请求头的请求（添加token）
        var request = URLRequest(url: url)
        
        request.setValue(UserModel.shared.token, forHTTPHeaderField: "Authorization")
        
        webView.load(request)
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
    
    // MARK: - Cookie 注入
    private func injectCookies(to userContentController: WKUserContentController, for urlString: String) {
        // 检查是否需要注入 Cookie（替换为你的实际域名判断逻辑）
        guard urlString.contains(NetworkAPI.baseWebURL) else { // 替换为你的 kBase_web_url
            return
        }
        
        // 获取应用版本
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        
        // 创建 Cookie 注入脚本 - 只注入平台和版本信息
        let cookieScript = """
        document.cookie = 'platform=ios';
        document.cookie = 'versions=\(appVersion)';
        """
        
        let script = WKUserScript(
            source: cookieScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        userContentController.addUserScript(script)
        
        print("Cookie 注入完成: platform=ios, versions=\(appVersion)")
    }
}
