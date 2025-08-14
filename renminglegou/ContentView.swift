//
//  ContentView.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var userModel = UserModel.shared
    
    var body: some View {
        if let localPath = Bundle.main.path(forResource: "webview_test", ofType: "html") {
            let localURL = URL(fileURLWithPath: localPath)
            
            WebViewPage(
                url: localURL,
                defaultTitle: "任务中心测试"
            )
        } else {
            // 备用：使用原来的网络 URL
            WebViewPage(
                url: URL(string: "https://your-original-url.com")!,
                defaultTitle: "原始页面"
            )
        }
//        
//        WebViewPage(
//            url: URL(string: Constants.API.baseWebURL)!,
//            defaultTitle: ""
//        )
    }
}

#Preview {
    ContentView()
}
