//
//  renminglegouApp.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI

@main
struct renminglegouApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @ObservedObject private var sdkManager = SDKManager.shared
    @StateObject private var router = Router.shared

    init() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTManager.shared.requestTrackingAuthorization()
        }
        // 启动所有SDK初始化
        sdkManager.startAllSDKs()
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
                    case .djxPlaylet(config: let config):
                        DJXPlayletView(config: config)
                            .background(Color.black)
                            .navigationBarHidden(true)
                    }
                }
            }
            .overlay(content: {
                // 全局 Loading
                PureSwiftUILoadingView()
                    .onReceive(PureLoadingManager.shared.$isShowingLoading) { isShowing in
                        Logger.info("RootView收到Loading状态变化: \(isShowing)", category: .ui)
                    }
            })
            .environmentObject(router)
            .environmentObject(sdkManager)
            .environmentObject(sdkManager.getAdSlotManager())
            .onChange(of: sdkManager.allCriticalSDKsInitialized) { allReady in
                if allReady {
                    Logger.success("所有关键SDK初始化完成", category: .general)
                    sdkManager.logSDKStatus()
                }
            }
        }
    }
}
