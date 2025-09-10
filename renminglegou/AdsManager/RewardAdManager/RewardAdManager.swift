//
//  RewardAdManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import BUAdSDK

// MARK: - 激励广告管理器
class RewardAdManager {
    
    // MARK: - 单例
    static let shared = RewardAdManager()
    
    // MARK: - 属性
    private var adManagers: [String: SingleRewardAdManager] = [:]
    private let queue = DispatchQueue(label: "com.rewardad.manager", attributes: .concurrent)
    
    private init() {}
    
    // MARK: - 核心方法
    
    /// 为指定广告位创建管理器
    /// - Parameter slotID: 广告位ID
    /// - Returns: 广告管理器实例
    @discardableResult
    private func createManager(for slotID: String) -> SingleRewardAdManager {
        return queue.sync(flags: .barrier) {
            if let existingManager = adManagers[slotID] {
                return existingManager
            }
            
            let manager = SingleRewardAdManager(slotID: slotID)
            adManagers[slotID] = manager
            return manager
        }
    }
    
    /// 获取指定广告位的管理器
    /// - Parameter slotID: 广告位ID
    /// - Returns: 广告管理器实例，如果不存在则创建
    private func getManager(for slotID: String) -> SingleRewardAdManager {
        return createManager(for: slotID)
    }
    
    // MARK: - 便捷方法
    
    /// 预加载广告
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - completion: 完成回调
    func preloadAd(for slotID: String, completion: RewardAdLoadCallback? = nil) {
        let manager = getManager(for: slotID)
        manager.preloadAd(completion: completion)
    }
    
    /// 展示广告（简化版本）
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - viewController: 展示的视图控制器
    ///   - eventHandler: 事件处理器
    ///   - autoLoad: 是否自动加载
    func showAd(for slotID: String,
                from viewController: UIViewController,
                eventHandler: @escaping RewardAdEventCallback,
                autoLoad: Bool = true) {
        
        let manager = getManager(for: slotID)
        manager.showAd(from: viewController, eventCallback: eventHandler, autoLoad: autoLoad)
    }
    
    /// 展示广告（完整版本）
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - viewController: 展示的视图控制器
    ///   - eventHandler: 事件处理器
    ///   - completion: 展示结果回调
    ///   - autoLoad: 是否自动加载
    func showAd(for slotID: String,
                from viewController: UIViewController,
                eventHandler: RewardAdEventCallback? = nil,
                completion: RewardAdShowCallback? = nil,
                autoLoad: Bool = true) {
        
        let manager = getManager(for: slotID)
        manager.showAd(from: viewController, eventCallback: eventHandler, completion: completion, autoLoad: autoLoad)
    }
    
    /// 设置全局事件监听
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - eventHandler: 事件处理器
    func setEventHandler(for slotID: String, eventHandler: @escaping RewardAdEventCallback) {
        let manager = getManager(for: slotID)
        manager.setEventCallback(eventHandler)
    }
    
    /// 批量预加载广告
    /// - Parameter slotIDs: 广告位ID数组
    func preloadAds(for slotIDs: [String]) {
        slotIDs.forEach { slotID in
            preloadAd(for: slotID)
        }
    }
    
    // MARK: - 状态查询方法
    
    /// 检查指定广告位是否已加载
    /// - Parameter slotID: 广告位ID
    /// - Returns: 是否已加载
    func isAdReady(for slotID: String) -> Bool {
        return queue.sync {
            return adManagers[slotID]?.isReady ?? false
        }
    }
    
    /// 检查指定广告位是否正在加载
    /// - Parameter slotID: 广告位ID
    /// - Returns: 是否正在加载
    func isAdLoading(for slotID: String) -> Bool {
        return queue.sync {
            return adManagers[slotID]?.isLoading ?? false
        }
    }
    
    /// 检查指定广告位是否正在展示
    /// - Parameter slotID: 广告位ID
    /// - Returns: 是否正在展示
    func isAdShowing(for slotID: String) -> Bool {
        return queue.sync {
            return adManagers[slotID]?.isShowing ?? false
        }
    }
    
    /// 获取指定广告位的状态
    /// - Parameter slotID: 广告位ID
    /// - Returns: 广告状态
    func getAdState(for slotID: String) -> RewardAdState {
        return queue.sync {
            return adManagers[slotID]?.adState ?? .initial
        }
    }
    
    /// 获取指定广告位的状态描述
    /// - Parameter slotID: 广告位ID
    /// - Returns: 状态描述
    func getStateDescription(for slotID: String) -> String {
        return queue.sync {
            return adManagers[slotID]?.stateDescription ?? "未初始化"
        }
    }
    
    // MARK: - 配置方法
    
    /// 设置自动重加载
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - autoReload: 是否自动重加载
    func setAutoReload(for slotID: String, autoReload: Bool) {
        let manager = getManager(for: slotID)
        manager.autoReloadAfterClose = autoReload
    }
    
    // MARK: - 销毁方法
    
    /// 销毁指定广告位的管理器
    /// - Parameter slotID: 广告位ID
    func destroyManager(for slotID: String) {
        queue.sync(flags: .barrier) {
            adManagers[slotID]?.destroyAd()
            adManagers.removeValue(forKey: slotID)
        }
    }
    
    /// 销毁所有广告管理器
    func destroyAllManagers() {
        queue.sync(flags: .barrier) {
            adManagers.values.forEach { $0.destroyAd() }
            adManagers.removeAll()
        }
    }
    
    /// 获取当前管理的广告位数量
    var managedSlotCount: Int {
        return queue.sync {
            return adManagers.count
        }
    }
    
    /// 获取所有管理的广告位ID
    var managedSlotIDs: [String] {
        return queue.sync {
            return Array(adManagers.keys)
        }
    }
}
