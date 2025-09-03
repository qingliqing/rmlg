//
//  WebViewCoordinator.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import WebKit
import UIKit
import SwiftUICore

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: WebViewWrapper
    weak var currentWebView: WKWebView?
    
    init(_ parent: WebViewWrapper) {
        self.parent = parent
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let topViewController = getTopViewController()
        H5MessageHandler.receiveScriptMessage(
            message,
            selfVC: topViewController,
            webView: currentWebView
        )
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("WebView 页面加载完成")
        
        // 保存 webView 引用
        currentWebView = webView
        
        // 立即尝试获取标题
        updateTitle(from: webView)
        
        // 延迟再次获取标题（确保页面完全加载）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.updateTitle(from: webView)
        }
        
        // 监听标题变化
        webView.addObserver(self, forKeyPath: "title", options: .new, context: nil)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("WebView 加载失败: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        H5MessageHandler.h5CallJSReturnValue(prompt: prompt, completionHandler: completionHandler)
    }
    
    // KVO 监听标题变化
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "title", let webView = object as? WKWebView {
            updateTitle(from: webView)
        }
    }
    
    // 更新标题的统一方法
    private func updateTitle(from webView: WKWebView) {
        if let title = webView.title, !title.isEmpty {
            DispatchQueue.main.async {
                self.parent.pageTitle = title
            }
        }
    }
    
    // 获取当前顶层 ViewController 的辅助方法
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        return getTopViewController(from: window.rootViewController)
    }
    
    private func getTopViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigationController = viewController as? UINavigationController {
            return getTopViewController(from: navigationController.visibleViewController)
        }
        
        if let tabController = viewController as? UITabBarController {
            return getTopViewController(from: tabController.selectedViewController)
        }
        
        if let presentedViewController = viewController?.presentedViewController {
            return getTopViewController(from: presentedViewController)
        }
        
        return viewController
    }
    
    deinit {
        // 移除 KVO 监听
        currentWebView?.removeObserver(self, forKeyPath: "title")
    }
}
