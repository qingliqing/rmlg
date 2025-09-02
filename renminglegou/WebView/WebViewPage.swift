//
//  WebViewPage.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI

struct WebViewPage: View {
    @State private var pageTitle: String = ""
    @State private var currentURL: URL
    @StateObject private var authState = AuthenticationState.shared

    let defaultTitle: String
    let showBackButton: Bool

    init(url: URL, title: String = "", showBackButton: Bool = false) {
        _currentURL = State(initialValue: url)
        self.defaultTitle = title
        self.showBackButton = showBackButton
    }

    var body: some View {
        VStack(spacing: 0) {
            // 自定义导航栏
            HStack {
                if showBackButton {
                    Button {
                        // 返回逻辑，可以用 Router 或 dismiss
                        Router.pop()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                    }
                }

                Text(pageTitle.isEmpty ? defaultTitle : pageTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)

                if showBackButton {
                    Spacer()
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))

            // WebView
            WebViewWrapper(
                url: currentURL,
                pageTitle: $pageTitle
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { pageTitle = defaultTitle }
        .onReceive(authState.$isAuthenticated) { isAuth in
            if !isAuth {
                // 登录失效，跳转到登录页面
                currentURL = URL(string: NetworkAPI.baseWebURL + NetworkAPI.loginWebURL)!
            }
        }
    }
}
