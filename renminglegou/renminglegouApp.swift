//
//  renminglegouApp.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI
import BUAdSDK

@main
struct renminglegouApp: App {
    @ObservedObject private var adSDKManager = AdSDKManager.shared
    @StateObject private var router = Router.shared

    init() {
        adSDKManager.startSDK() // 初始化 SDK
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                RootView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .splash:
                        SplashView()
                    case .webView(let url, let title, let showBackButton):
                        WebViewPage(url: url, title: title, showBackButton: showBackButton)
                    case .taskCenter(_):
                        TaskCenterView()
                    }
                }
            }
            .overlay(content: {
                // 3️⃣ 全局 Loading
                PureSwiftUILoadingView()
                    .onReceive(PureLoadingManager.shared.$isShowingLoading) { isShowing in
                        print("🌍 RootView收到Loading状态变化: \(isShowing)")
                    }
            })
            .environmentObject(router)
            .environmentObject(adSDKManager)
        }
    }
}

// MARK: - 广告 SDK 管理器
class AdSDKManager: ObservableObject {
    static let shared = AdSDKManager()
    
    @Published var isInitialized: Bool = false
    
    private init() {}
    
    func startSDK() {
        let configuration = BUAdSDKConfiguration()
        configuration.useMediation = true
        configuration.appID = "5706508"
        configuration.mediation.limitPersonalAds = 0
        configuration.mediation.limitProgrammaticAds = 0
        configuration.themeStatus = 0
        
        BUAdSDKManager.start(syncCompletionHandler: { success, error in
            DispatchQueue.main.async {
                self.isInitialized = success
                print(success ? "SDK 初始化成功" : "SDK 初始化失败: \(error?.localizedDescription ?? "未知错误")")
            }
        })
    }
}
