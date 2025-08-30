//
//  WebViewPage.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI

struct WebViewPage: View {
    let url: URL
    let defaultTitle: String
    let showBackButton: Bool
    
    @State private var pageTitle: String = ""
    @EnvironmentObject var navigationManager: NavigationManager
    
    // 初始化方法 - 添加可选参数
    init(url: URL, defaultTitle: String = "", showBackButton: Bool = true) {
        self.url = url
        self.defaultTitle = defaultTitle
        self.showBackButton = showBackButton
    }
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            VStack(spacing: 0) {
                // 自定义导航栏
                HStack {
                    // 返回按钮（条件显示）
                    if showBackButton {
                        Button(action: {
                            // 检查导航栈是否有内容
                            if !navigationManager.path.isEmpty {
                                navigationManager.path.removeLast()
                            } else {
                                // 如果没有导航栈，可以使用其他返回逻辑
                                // 比如 dismiss 或者其他处理
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                    }
                    
                    // 标题
                    Text(pageTitle.isEmpty ? defaultTitle : pageTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: showBackButton ? .center : .leading)
                    
                    // 占位符（保持布局平衡）
                    if showBackButton {
                        Spacer()
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                
                // WebView
                WebViewWrapper(
                    url: url,
                    pageTitle: $pageTitle,
                    navigationManager: navigationManager
                )
            }
            .navigationBarHidden(true) // 隐藏系统导航栏，使用自定义的
            .navigationDestination(for: NavigationDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .onAppear {
            pageTitle = defaultTitle
        }
    }
    
    @ViewBuilder
    private func destinationView(for destination: NavigationDestination) -> some View {
        switch destination {
        case .taskCenter(_):
            TaskCenterView()
        case .webView(url: let url, title: let title, showBackButton: let showBackButton):
                WebViewPage(url: url, defaultTitle: title, showBackButton: showBackButton)
        }
    }
}
