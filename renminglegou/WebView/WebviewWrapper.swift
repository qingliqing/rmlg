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
        webView.load(URLRequest(url: url))
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(self)
    }
}
