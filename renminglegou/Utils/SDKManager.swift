//
//  SDKManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/9/10.
//

import Foundation
import SwiftUI
import BUAdSDK
import PangrowthDJX
import Network
import Combine

/// 统一的SDK管理器，负责管理所有第三方SDK的初始化
@MainActor
class SDKManager: ObservableObject {
    
    static let shared = SDKManager()
    
    // MARK: - Published Properties
    @Published var adSDKInitialized = false
    @Published var djxSDKInitialized = false
    @Published var adSlotManagerInitialized = false
    @Published var isNetworkConnected = false
    @Published var networkConnectionType = "未知"
    
    // MARK: - Private Properties
    private let adSDKManager = AdSDKManager()
    private let djxSDKManager = DJXSDKManager()
    private let adSlotManager = AdSlotManager.shared
    private let networkMonitor = NetworkMonitor()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 所有关键SDK是否都已初始化
    var allCriticalSDKsInitialized: Bool {
        return adSDKInitialized && adSlotManagerInitialized
    }
    
    var isAdSDKReady: Bool {
        return BUAdSDKManager.state == .start
    }
    
    /// 初始化状态信息
    var initializationStatus: String {
        var status = ["初始化状态:"]
        status.append("广告SDK: \(adSDKInitialized ? "✅" : "❌")")
        status.append("短剧SDK: \(djxSDKInitialized ? "✅" : "❌")")
        status.append("广告位管理: \(adSlotManagerInitialized ? "✅" : "❌")")
        status.append("网络连接: \(isNetworkConnected ? "✅" : "❌")")
        return status.joined(separator: " | ")
    }
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
    }
    
    /// 启动所有SDK初始化
    func startAllSDKs() {
        Logger.info("开始初始化所有SDK", category: .general)
        
        // 1. 首先初始化不依赖网络的SDK
        startAdSDK()
        startDJXSDK()
        
        // 2. 开始网络监控
        networkMonitor.startMonitoring()
    }
    
    // MARK: - Private Methods
    
    /// 设置数据绑定
    private func setupBindings() {
        // 监听各个SDK的初始化状态
        adSDKManager.$isInitialized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                self?.adSDKInitialized = isInitialized
            }
            .store(in: &cancellables)
        
        djxSDKManager.$isInitialized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                self?.djxSDKInitialized = isInitialized
            }
            .store(in: &cancellables)
        
        adSlotManager.$isInitialized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isInitialized in
                self?.adSlotManagerInitialized = isInitialized
            }
            .store(in: &cancellables)
        
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isNetworkConnected = isConnected
            }
            .store(in: &cancellables)
        
        networkMonitor.$connectionType
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connectionType in
                self?.networkConnectionType = connectionType
            }
            .store(in: &cancellables)
        
        // 当广告SDK和网络都准备好时，初始化广告位管理器
        Publishers.CombineLatest($adSDKInitialized, $isNetworkConnected)
            .filter { adSDKReady, networkReady in
                adSDKReady && networkReady
            }
            .first() // 只取第一次满足条件的值
            .sink { [weak self] _, _ in
                Task {
                    await self?.initializeAdSlotManager()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 初始化广告SDK
    private func startAdSDK() {
        Logger.info("开始初始化广告SDK", category: .general)
        adSDKManager.startSDK()
    }
    
    /// 初始化短剧SDK
    private func startDJXSDK() {
        Logger.info("开始初始化短剧SDK", category: .general)
        djxSDKManager.startLCDSDK()
    }
    
    /// 初始化广告位管理器
    private func initializeAdSlotManager() async {
        guard !adSlotManager.isInitialized && !adSlotManager.isLoading else {
            return // 避免重复初始化
        }
        
        Logger.info("开始初始化广告位管理器", category: .adSlot)
        await adSlotManager.initializeOnAppLaunch()
    }
    
    /// 获取各个SDK管理器的引用（供需要时使用）
    fileprivate func getAdSDKManager() -> AdSDKManager {
        return adSDKManager
    }
    
    fileprivate func getDJXSDKManager() -> DJXSDKManager {
        return djxSDKManager
    }
    
    func getAdSlotManager() -> AdSlotManager {
        return adSlotManager
    }
    
    /// 打印SDK状态信息（调试用）
    func logSDKStatus() {
        Logger.info(initializationStatus, category: .general)
        
        // 详细状态
        let detailStatus = """
        详细SDK状态:
        - 广告SDK: \(adSDKInitialized ? "已初始化" : "未初始化")
        - 短剧SDK: \(djxSDKInitialized ? "已初始化" : "未初始化") 
        - 广告位管理器: \(adSlotManagerInitialized ? "已初始化" : "未初始化")
        - 网络状态: \(isNetworkConnected ? "已连接(\(networkConnectionType))" : "未连接")
        - 关键SDK状态: \(allCriticalSDKsInitialized ? "全部就绪" : "等待中")
        """
        
        Logger.debug(detailStatus, category: .general)
    }
}

// MARK: - 广告 SDK 管理器
private class AdSDKManager: ObservableObject {
    @Published var isInitialized: Bool = false
    
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
        
        BUAdSDKManager.start(syncCompletionHandler: { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isInitialized = success
                if success {
                    Logger.success("广告SDK 初始化成功", category: .general)
                } else {
                    Logger.error("广告SDK 初始化失败: \(error?.localizedDescription ?? "未知错误")", category: .general)
                }
            }
        })
    }
}

// MARK: - 短剧 SDK 管理器
private class DJXSDKManager: NSObject, ObservableObject {
    @Published var isInitialized: Bool = false
    @Published var initializationMessage: String = ""
    
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
            Logger.error("短剧SDK 配置文件未找到", category: .general)
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
                    Logger.success("短剧SDK 初始化注册成功", category: .general)
                } else {
                    let errorMsg = userInfo["msg"] as? String ?? "未知错误"
                    self?.initializationMessage = "短剧SDK初始化失败: \(errorMsg)"
                    Logger.error("短剧SDK 初始化失败: \(errorMsg)", category: .general)
                }
            }
        }
    }
}

// MARK: - DJXAuthorityConfigDelegate
extension DJXSDKManager: DJXAuthorityConfigDelegate {
    // 实现 DJXAuthorityConfigDelegate 的必要方法
    // 根据 SDK 文档添加具体的代理方法实现
}

// MARK: - 网络监控器
private class NetworkMonitor: ObservableObject {
    @Published var isConnected = false
    @Published var connectionType: String = "未知"
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(for: path) ?? "未知"
                
                if path.status == .satisfied {
                    Logger.network("网络连接已建立: \(self?.connectionType ?? "")")
                } else {
                    Logger.warning("网络连接断开", category: .network)
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(for path: NWPath) -> String {
        if path.usesInterfaceType(.wifi) {
            return "WiFi"
        } else if path.usesInterfaceType(.cellular) {
            return "蜂窝网络"
        } else if path.usesInterfaceType(.wiredEthernet) {
            return "有线网络"
        } else {
            return "其他"
        }
    }
    
    deinit {
        monitor.cancel()
    }
}
