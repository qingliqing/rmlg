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
    
    @State private var pageTitle: String = ""
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some View {
        NavigationStack(path: $navigationManager.path) {
            VStack(spacing: 0) {
                // 自定义导航栏
                HStack {
                    Text(pageTitle.isEmpty ? defaultTitle : pageTitle)
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(radius: 1)
                
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
        case .taskCenter(let params):
            TaskCenterView()
        }
    }
}
