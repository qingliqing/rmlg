//
//  renminglegouApp.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI
import BUAdSDK
import PangrowthDJX

@main
struct renminglegouApp: App {
    @ObservedObject private var adSDKManager = AdSDKManager.shared
    @ObservedObject private var djxSDKManager = DJXSDKManager.shared
    @StateObject private var router = Router.shared

    init() {
        adSDKManager.startSDK() // 初始化广告 SDK
        djxSDKManager.startLCDSDK() // 初始化短剧 SDK
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
                        print("🌍 RootView收到Loading状态变化: \(isShowing)")
                    }
            })
            .environmentObject(router)
            .environmentObject(adSDKManager)
            .environmentObject(djxSDKManager)
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
        
#if DEBUG
        configuration.debugLog = 1
#endif
        
        BUAdSDKManager.start(syncCompletionHandler: { success, error in
            DispatchQueue.main.async {
                self.isInitialized = success
                print(success ? "✅ 广告SDK 初始化成功" : "❌ 广告SDK 初始化失败: \(error?.localizedDescription ?? "未知错误")")
            }
        })
    }
}

// MARK: - 短剧 SDK 管理器
class DJXSDKManager: NSObject, ObservableObject {
    static let shared = DJXSDKManager()
    
    @Published var isInitialized: Bool = false
    @Published var initializationMessage: String = ""

    private override init() {
        super.init()
    }
    
    /// 初始化短剧SDK
    func startLCDSDK() {
        let config = DJXConfig()
        config.authorityDelegate = self
        
#if DEBUG
        config.logLevel = .debug
#endif
        
        guard let configPath = Bundle.main.path(forResource: "SDK_Setting_5706508", ofType: "json") else {
            DispatchQueue.main.async {
                self.isInitialized = false
                self.initializationMessage = "配置文件未找到"
            }
            print("❌ 短剧SDK 配置文件未找到")
            return
        }
        
        // 数据配置，可在app初始化时调用
        DJXManager.initialize(withConfigPath: configPath, config: config)
        
        // 正在初始化，可在进入实际场景前使用
        DJXManager.start { [weak self] initStatus, userInfo in
            DispatchQueue.main.async {
                self?.isInitialized = initStatus
                
                if initStatus {
                    self?.initializationMessage = "短剧SDK初始化成功"
                    print("✅ 短剧SDK 初始化注册成功！")
                } else {
                    let errorMsg = userInfo["msg"] as? String ?? "未知错误"
                    self?.initializationMessage = "短剧SDK初始化失败: \(errorMsg)"
                    print("❌ 短剧SDK 初始化失败: \(errorMsg)")
                }
            }
        }
    }
}

// MARK: - DJXAuthorityConfigDelegate
extension DJXSDKManager : DJXAuthorityConfigDelegate{
    // 实现 DJXAuthorityConfigDelegate 的必要方法
    // 根据 SDK 文档添加具体的代理方法实现
    
    
    // 如果还有其他代理方法，请在这里添加
}
