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
    @StateObject private var adSDKManager = AdSDKManager.shared
    @StateObject private var navigationManager = NavigationManager()
    
    init() {
        adSDKManager.startSDK() // 初始化 SDK
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // ✅ 只有 SDK 初始化成功后才显示 SplashView
                if adSDKManager.isInitialized {
                    SplashView()
                } else {
                    // 初始化未完成前显示白屏或默认启动图
                    Color.white
                        .ignoresSafeArea()
                }
                
                PureSwiftUILoadingView()
            }
            .environmentObject(navigationManager)
            .environmentObject(adSDKManager)
        }
    }
}

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
