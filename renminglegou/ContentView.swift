//
//  ContentView.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authState = AuthenticationState.shared
    @StateObject private var userModel = UserModel.shared
    
    var body: some View {
        ZStack {
            let rootUrl = authState.isAuthenticated ? NetworkAPI.baseWebURL :NetworkAPI.baseWebURL+NetworkAPI.loginWebURL
            WebViewPage(
                url: URL(string: rootUrl)!,
                defaultTitle: ""
            )
//            debugView
        }
    }
    
    
    var debugView: some View {
        
        ZStack {
            // 主要的 WebView 内容
            if let localPath = Bundle.main.path(forResource: "webview_test", ofType: "html") {
                let localURL = URL(fileURLWithPath: localPath)
                
                WebViewPage(
                    url: localURL,
                    defaultTitle: "任务中心测试"
                )
            } else {
                // 备用：使用原来的网络 URL
                WebViewPage(
                    url: URL(string: NetworkAPI.baseWebURL)!,
                    defaultTitle: ""
                )
            }
            
            // Debug 模式下的测试按钮浮层
            if BUAdTestHelper.isTestMeasurementAvailable {
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            BUAdTestHelper.showTestMeasurement()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "wrench.and.screwdriver")
                                    .font(.system(size: 14, weight: .medium))
                                Text("测试工具")
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.orange)
                                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            )
                            .foregroundColor(.white)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 100) // 避免被底部安全区域遮挡
                    }
                }
            }
        }
    }
}

