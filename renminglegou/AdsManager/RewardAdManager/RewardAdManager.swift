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
    /// - Parameters:
    /// - slotID: 广告位ID
    /// - rewardConfig: 奖励配置
    /// - Returns: 广告管理器实例
    @discardableResult
    private func createManager(for slotID: String, rewardConfig: AdRewardConfig?) -> SingleRewardAdManager {
        return queue.sync(flags: .barrier) {
            if let existingManager = adManagers[slotID] {
                Logger.info("⚠️ 重复创建管理器 - 广告位: \(slotID)，返回现有实例")
                return existingManager
            }
            
            // 创建管理器时传入自动移除回调
            let manager = SingleRewardAdManager(
                slotID: slotID,
                rewardConfig: rewardConfig
            ) { [weak self] slotID in
                // 自动移除回调
                self?.removeManager(for: slotID)
            }
            
            adManagers[slotID] = manager
            Logger.info("✅ 创建新的广告管理器 - 广告位: \(slotID)，当前总数: \(adManagers.count)")
            return manager
        }
    }
    
    /// 获取指定广告位的管理器
    /// - Parameter slotID: 广告位ID
    /// - Returns: 广告管理器实例，如果不存在则返回nil
    private func getManager(for slotID: String) -> SingleRewardAdManager? {
        return queue.sync {
            return adManagers[slotID]
        }
    }
    
    /// 移除指定广告位的管理器
    /// - Parameter slotID: 广告位ID
    private func removeManager(for slotID: String) {
        queue.sync(flags: .barrier) {
            if let removedManager = adManagers.removeValue(forKey: slotID) {
                Logger.info("🗑️ 自动移除广告管理器 - 广告位: \(slotID)")
                Logger.info("📊 当前管理器数量: \(adManagers.count)")
                
                // 确保管理器被正确清理（防御性编程）
                // removedManager 会在这里失去引用，触发 deinit
            } else {
                Logger.info("⚠️ 尝试移除不存在的管理器 - 广告位: \(slotID)")
            }
        }
    }
    
    // MARK: - 便捷方法
    
    /// 预加载广告
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - rewardConfig: 奖励配置
    ///   - completion: 完成回调
    func preloadAd(for slotID: String, rewardConfig: AdRewardConfig? = nil, completion: RewardAdLoadCallback? = nil) {
        if let manager = getManager(for: slotID) {
            Logger.info("📲 使用现有管理器预加载广告 - 广告位: \(slotID)")
            manager.preloadAd(completion: completion)
        } else {
            Logger.info("📲 创建新管理器并预加载广告 - 广告位: \(slotID)")
            let manager = createManager(for: slotID, rewardConfig: rewardConfig)
            manager.preloadAd(completion: completion)
        }
    }
    
    /// 展示广告
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - rewardConfig: 奖励配置
    ///   - viewController: 展示的视图控制器
    ///   - eventHandler: 事件处理器
    ///   - completion: 展示结果回调
    ///   - autoLoad: 是否自动加载
    func showAd(for slotID: String,
                rewardConfig: AdRewardConfig? = nil,
                from viewController: UIViewController,
                eventHandler: RewardAdEventCallback? = nil,
                completion: RewardAdShowCallback? = nil,
                autoLoad: Bool = true) {
        
        if let manager = getManager(for: slotID) {
            Logger.info("📺 使用现有管理器展示广告 - 广告位: \(slotID)")
            manager.showAd(
                from: viewController,
                eventCallback: eventHandler,
                completion: completion,
                autoLoad: autoLoad
            )
        } else {
            Logger.info("📺 创建新管理器并展示广告 - 广告位: \(slotID)")
            let manager = createManager(for: slotID, rewardConfig: rewardConfig)
            manager.showAd(
                from: viewController,
                eventCallback: eventHandler,
                completion: completion,
                autoLoad: autoLoad
            )
        }
    }
    
    /// 设置全局事件监听
    /// - Parameters:
    ///   - slotID: 广告位ID
    ///   - eventHandler: 事件处理器
    func setEventHandler(for slotID: String, eventHandler: @escaping RewardAdEventCallback) {
        if let manager = getManager(for: slotID) {
            manager.setEventCallback(eventHandler)
        } else {
            Logger.info("⚠️ 尝试为不存在的管理器设置事件处理器 - 广告位: \(slotID)")
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
    
    /// 检查管理器是否存在
    /// - Parameter slotID: 广告位ID
    /// - Returns: 管理器是否存在
    func hasManager(for slotID: String) -> Bool {
        return queue.sync {
            return adManagers[slotID] != nil
        }
    }
    
    // MARK: - 手动销毁方法（通常不需要使用，但保留作为备用）
    
    /// 手动销毁指定广告位的管理器
    /// - Parameter slotID: 广告位ID
    /// - Note: 通常不需要手动调用，管理器会在广告播放完成后自动移除
    func destroyManager(for slotID: String) {
        queue.sync(flags: .barrier) {
            if let manager = adManagers.removeValue(forKey: slotID) {
                // 手动调用销毁，确保资源清理
                // manager 的 deinit 会自动调用 cleanupAllResources
                Logger.info("🔨 手动销毁广告管理器 - 广告位: \(slotID)")
            } else {
                Logger.info("⚠️ 尝试销毁不存在的管理器 - 广告位: \(slotID)")
            }
        }
    }
    
    /// 手动销毁所有广告管理器
    /// - Note: 通常在应用退出时调用
    func destroyAllManagers() {
        queue.sync(flags: .barrier) {
            let count = adManagers.count
            adManagers.removeAll() // 所有管理器会自动触发 deinit
            Logger.info("🔨 手动销毁所有广告管理器，数量: \(count)")
        }
    }
    
    // MARK: - 调试和监控方法
    
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
    
    /// 打印当前所有管理器的状态（调试用）
    func printAllManagersStatus() {
        queue.sync {
            Logger.info("📊 当前广告管理器状态报告:")
            Logger.info("📊 总管理器数量: \(adManagers.count)")
            
            if adManagers.isEmpty {
                Logger.info("📊 暂无活跃的广告管理器")
            } else {
                for (slotID, manager) in adManagers {
                    Logger.info("📊 广告位: \(slotID) - 状态: \(manager.stateDescription)")
                }
            }
        }
    }
}
