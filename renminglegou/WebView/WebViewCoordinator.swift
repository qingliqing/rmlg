//
//  WebViewCoordinator.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import WebKit
import UIKit
import SwiftUICore
import Network

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
   var parent: WebViewWrapper
   weak var currentWebView: WKWebView?
   private var monitor: NWPathMonitor?
   private var queue = DispatchQueue(label: "NetworkMonitor")
   
   // 状态跟踪
   private var hasLoadedSuccessfully = false
   private var lastLoadFailed = false
   private var wasDisconnected = false  // 记录是否曾经断网
   
   init(_ parent: WebViewWrapper) {
       self.parent = parent
       super.init()
       startNetworkMonitoring()
   }
   
   // MARK: - 网络监听
   private func startNetworkMonitoring() {
       monitor = NWPathMonitor()
       monitor?.pathUpdateHandler = { [weak self] path in
           DispatchQueue.main.async {
               if path.status == .satisfied {
                   // 网络已连接
                   if self?.wasDisconnected == true {
                       // 只有从断网恢复时才考虑刷新
                       print("网络从断开状态恢复")
                       self?.handleNetworkReconnected()
                       self?.wasDisconnected = false
                   }
               } else {
                   // 网络断开
                   print("网络已断开")
                   self?.wasDisconnected = true
               }
           }
       }
       monitor?.start(queue: queue)
   }
   
   private func handleNetworkReconnected() {
       // 延迟判断，避免频繁网络切换导致的误刷新
       DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
           guard self.shouldRefreshOnReconnect() else {
               print("网络恢复但无需刷新页面")
               return
           }
           
           print("网络恢复，需要刷新页面")
           self.refreshWebViewIfNeeded()
       }
   }
   
   private func shouldRefreshOnReconnect() -> Bool {
       guard let webView = currentWebView else { return false }
       
       // 满足以下任一条件才刷新：
       return lastLoadFailed ||                    // 上次加载失败
              !hasLoadedSuccessfully ||             // 从未成功加载过
              webView.url == nil ||                 // 没有加载任何URL
              isShowingErrorPage()                  // 显示错误页面
   }
   
   private func isShowingErrorPage() -> Bool {
       guard let webView = currentWebView else { return false }
       
       // 检查是否显示错误页面
       if let url = webView.url?.absoluteString {
           return url.contains("error") ||
                  url.hasPrefix("file://") ||
                  url.contains("about:blank")
       }
       
       // 通过标题判断
       if let title = webView.title {
           return title.contains("错误") ||
                  title.contains("无法连接") ||
                  title.contains("Error") ||
                  title.isEmpty
       }
       
       return false
   }
   
   private func refreshWebViewIfNeeded() {
       guard let webView = currentWebView else {
           print("WebView 引用为空，无法刷新")
           return
       }
       
       var request = URLRequest(url: parent.url)
       request.setValue(UserModel.shared.token, forHTTPHeaderField: "Authorization")
       webView.load(request)
       
       // 重置状态
       lastLoadFailed = false
   }
   
   // MARK: - WebView 代理方法
   func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
       print("WebView 页面加载完成")
       
       // 保存 webView 引用
       currentWebView = webView
       hasLoadedSuccessfully = true
       lastLoadFailed = false
       
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
       lastLoadFailed = true
       hasLoadedSuccessfully = false
   }
   
   func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
       print("WebView 初始加载失败: \(error.localizedDescription)")
       lastLoadFailed = true
       hasLoadedSuccessfully = false
   }
   
   // MARK: - 消息处理
   func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
       let topViewController = getTopViewController()
       H5MessageHandler.receiveScriptMessage(
           message,
           selfVC: topViewController,
           webView: currentWebView
       )
   }
   
   func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
       H5MessageHandler.h5CallJSReturnValue(prompt: prompt, completionHandler: completionHandler)
   }
   
   // MARK: - KVO 监听标题变化
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
   
   // MARK: - 获取顶层 ViewController
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
       monitor?.cancel()
       currentWebView?.removeObserver(self, forKeyPath: "title")
   }
}
