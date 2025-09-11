//
//  SingleRewardAdManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/30.
//

import BUAdSDK

// MARK: - 回调类型定义
typealias RewardAdEventCallback = (RewardAdEvent) -> Void
typealias RewardAdLoadCallback = (Result<Void, Error>) -> Void
typealias RewardAdShowCallback = (Result<Void, Error>) -> Void

// MARK: - 单个广告位管理器
class SingleRewardAdManager: NSObject {
    
    // MARK: - 属性（添加自动移除回调）
    private var rewardedVideoAd: BUNativeExpressRewardedVideoAd?
    private var rewardedVideoModel: BURewardedVideoModel?
    private let adSlotID: String
    private var currentState: RewardAdState = .initial
    private var rewardConfig: AdRewardConfig?
    
    // 回调存储
    private var eventCallback: RewardAdEventCallback?
    private var loadCallbacks: [RewardAdLoadCallback] = []
    private var pendingShowRequest: (UIViewController, RewardAdEventCallback?, RewardAdShowCallback?)?
    
    // 超时管理
    private var loadingTimer: Timer?
    private let loadTimeout: TimeInterval = 15.0
    
    // 【新增】自动移除回调
    private var autoRemoveCallback: ((String) -> Void)?
    
    // MARK: - 初始化（修改构造函数）
    init(slotID: String,
         rewardConfig: AdRewardConfig?,
         autoRemoveCallback: ((String) -> Void)? = nil) {
        self.adSlotID = slotID
        self.rewardConfig = rewardConfig
        self.autoRemoveCallback = autoRemoveCallback
        super.init()
        Logger.info("广告管理器初始化完成 - 广告位: \(adSlotID)")
    }
    
    // MARK: - 析构函数（确保资源清理）
    deinit {
        Logger.info("🗑️ 广告管理器即将释放 - 广告位: \(adSlotID)")
        cleanupAllResources()
    }
    
    // MARK: - 公开方法
    
    /// 设置事件回调（监听所有事件）
    func setEventCallback(_ callback: RewardAdEventCallback?) {
        self.eventCallback = callback
    }
    
    /// 预加载广告
    func preloadAd(completion: RewardAdLoadCallback? = nil) {
        if let completion = completion {
            loadCallbacks.append(completion)
        }
        
        guard currentState != .loading else {
            Logger.info("广告位 \(adSlotID) 正在加载中...")
            return
        }
        
        if isReady {
            Logger.info("广告位 \(adSlotID) 已准备就绪")
            executeLoadCallbacks(.success(()))
            return
        }
        
        startLoading()
    }
    
    /// 展示广告
    func showAd(from viewController: UIViewController,
                eventCallback: RewardAdEventCallback? = nil,
                completion: RewardAdShowCallback? = nil,
                autoLoad: Bool = true) {
        
        if let eventCallback = eventCallback {
            self.eventCallback = eventCallback
        }
        
        switch currentState {
        case .loaded, .videoDownloaded:
            performShow(from: viewController, completion: completion)
            
        case .loading:
            Logger.info("广告正在加载中，加入等待队列")
            pendingShowRequest = (viewController, eventCallback, completion)
            
        case .showing:
            let error = NSError(domain: "RewardAdManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "广告正在展示"])
            completion?(.failure(error))
            
        default:
            if autoLoad {
                Logger.info("广告未准备就绪，开始自动加载")
                pendingShowRequest = (viewController, eventCallback, completion)
                preloadAd { [weak self] result in
                    switch result {
                    case .success:
                        self?.handlePendingShow()
                    case .failure(let error):
                        self?.pendingShowRequest?.2?(.failure(error))
                        self?.pendingShowRequest = nil
                    }
                }
            } else {
                let error = NSError(domain: "RewardAdManager", code: -2,
                                  userInfo: [NSLocalizedDescriptionKey: "广告未准备就绪"])
                completion?(.failure(error))
            }
        }
    }
    
    // MARK: - 状态查询
    var isReady: Bool {
        return currentState == .loaded || currentState == .videoDownloaded
    }
    
    var isLoading: Bool {
        return currentState == .loading
    }
    
    var isShowing: Bool {
        return currentState == .showing
    }
    
    var adState: RewardAdState { return currentState }
    var slotID: String { return adSlotID }
    
    var stateDescription: String {
        switch currentState {
        case .initial: return "初始状态"
        case .loading: return "加载中"
        case .loaded: return "加载完成，可以展示"
        case .loadFailed: return "加载失败"
        case .videoDownloaded: return "视频素材下载完成"
        case .showing: return "正在展示"
        case .showFailed: return "展示失败"
        case .clicked: return "广告被点击"
        case .skipped: return "广告被跳过"
        case .playFinished: return "播放完成"
        case .playFailed: return "播放失败"
        case .rewardSuccess: return "奖励发放成功"
        case .rewardFailed: return "奖励发放失败"
        case .closed: return "广告关闭"
        }
    }
    
    // MARK: - 私有方法
    
    /// 完全清理所有资源
    private func cleanupAllResources() {
        cleanupCurrentAd()
        destroyAdObject()
        
        // 清理回调
        eventCallback = nil
        loadCallbacks.removeAll()
        pendingShowRequest = nil
        autoRemoveCallback = nil
        rewardConfig = nil
        
        Logger.info("所有资源已清理 - 广告位: \(adSlotID)")
    }
    
    /// 创建奖励视频广告对象
    private func createRewardedVideoAd() {
        if rewardedVideoAd != nil {
            destroyAdObject()
        }
        
        let slot = BUAdSlot()
        slot.id = adSlotID
        slot.mediation.mutedIfCan = false
        
        let rewardedVideoModel = BURewardedVideoModel()
        self.rewardedVideoModel = rewardedVideoModel
        let userId = "ios_\(UserModel.shared.userId)_\(Int64(Date().timeIntervalSince1970 * 1000))"
        rewardedVideoModel.userId = userId
        if let config = rewardConfig,
           let amount = config.points,
           let name = config.rewardDescription {
            rewardedVideoModel.rewardAmount = amount
            rewardedVideoModel.rewardName = name
        }
        
        let rewardedVideoAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: rewardedVideoModel)
        rewardedVideoAd.delegate = self
        rewardedVideoAd.rewardPlayAgainInteractionDelegate = self
        rewardedVideoAd.mediation?.addParam(NSNumber(value: 0), withKey: "show_direction")
        
        self.rewardedVideoAd = rewardedVideoAd
        
        Logger.info("新广告对象创建完成 - 广告位: \(adSlotID)")
    }
    
    /// 销毁广告对象
    private func destroyAdObject() {
        if let ad = rewardedVideoAd {
            ad.delegate = nil
            ad.rewardPlayAgainInteractionDelegate = nil
            self.rewardedVideoAd = nil
            Logger.info("广告对象已销毁 - 广告位: \(adSlotID)")
        }
        self.rewardedVideoModel = nil
    }
    
    private func startLoading() {
        createRewardedVideoAd()
        currentState = .loading
        notifyEvent(.loadStarted)
        
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadTimeout()
        }
        
        rewardedVideoAd?.loadData()
        Logger.info("开始加载广告 - 广告位: \(adSlotID)")
    }
    
    private func cleanupCurrentAd() {
        loadingTimer?.invalidate()
        loadingTimer = nil
    }
    
    private func handleLoadTimeout() {
        Logger.info("⚠️ 广告加载超时 - 广告位: \(adSlotID)")
        let error = NSError(domain: "RewardAdManager", code: -100,
                          userInfo: [NSLocalizedDescriptionKey: "广告加载超时"])
        
        currentState = .loadFailed
        notifyEvent(.loadFailed(error))
        executeLoadCallbacks(.failure(error))
        
        if let (_, _, completion) = pendingShowRequest {
            pendingShowRequest = nil
            completion?(.failure(error))
        }
        
        cleanupCurrentAd()
        destroyAdObject()
    }
    
    private func performShow(from viewController: UIViewController, completion: RewardAdShowCallback?) {
        guard let ad = rewardedVideoAd else {
            let error = NSError(domain: "RewardAdManager", code: -3,
                              userInfo: [NSLocalizedDescriptionKey: "广告对象不存在"])
            completion?(.failure(error))
            return
        }
        
        currentState = .showing
        notifyEvent(.showStarted)
        completion?(.success(()))
        
        ad.show(fromRootViewController: viewController)
    }
    
    private func handlePendingShow() {
        if let (viewController, eventCallback, completion) = pendingShowRequest {
            pendingShowRequest = nil
            if let eventCallback = eventCallback {
                self.eventCallback = eventCallback
            }
            performShow(from: viewController, completion: completion)
        }
    }
    
    private func executeLoadCallbacks(_ result: Result<Void, Error>) {
        let callbacks = loadCallbacks
        loadCallbacks.removeAll()
        
        DispatchQueue.main.async {
            callbacks.forEach { $0(result) }
        }
    }
    
    private func notifyEvent(_ event: RewardAdEvent) {
        DispatchQueue.main.async {
            self.eventCallback?(event)
            Logger.info("📺 广告事件 - 广告位: \(self.adSlotID), 事件: \(event.description)")
        }
    }
    
    /// 触发自动移除 - 新增方法
    private func triggerAutoRemove() {
        Logger.info("🗑️ 触发自动移除 - 广告位: \(adSlotID)")
        autoRemoveCallback?(adSlotID)
    }
}

// MARK: - SDK代理实现
extension SingleRewardAdManager: BUMNativeExpressRewardedVideoAdDelegate {
    
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        Logger.info("✅ 广告加载成功 - 广告位: \(adSlotID)")
        currentState = .loaded
        notifyEvent(.loadSuccess)
        executeLoadCallbacks(.success(()))
        handlePendingShow()
    }
    
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        Logger.info("❌ 广告加载失败 - 广告位: \(adSlotID), 错误: \(error?.localizedDescription ?? "未知错误")")
        currentState = .loadFailed
        let adError = error ?? NSError(domain: "RewardAdManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "广告加载失败"])
        
        notifyEvent(.loadFailed(adError))
        executeLoadCallbacks(.failure(adError))
        
        if let (_, _, completion) = pendingShowRequest {
            pendingShowRequest = nil
            completion?(.failure(adError))
        }
        
        cleanupCurrentAd()
        destroyAdObject()
    }
    
    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Logger.info("📥 广告素材下载完成 - 广告位: \(adSlotID)")
        currentState = .videoDownloaded
        notifyEvent(.videoDownloaded)
    }
    
    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Logger.info("👀 广告展示成功 - 广告位: \(adSlotID)")
        notifyEvent(.showSuccess)
        
        if let info = rewardedVideoAd.mediation?.getShowEcpmInfo() {
            Logger.info("💰 广告信息 - 广告位: \(adSlotID), ecpm: \(info.ecpm ?? "None"), platform: \(info.adnName)")
        }
    }
    
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
        Logger.info("❌ 广告展示失败 - 广告位: \(adSlotID), 错误: \(error.localizedDescription)")
        currentState = .showFailed
        notifyEvent(.showFailed(error))
        
        cleanupCurrentAd()
        destroyAdObject()
    }
    
    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Logger.info("👆 广告被点击 - 广告位: \(adSlotID)")
        currentState = .clicked
        notifyEvent(.clicked)
    }
    
    func nativeExpressRewardedVideoAdDidClickSkip(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Logger.info("⏭️ 广告被跳过 - 广告位: \(adSlotID)")
        currentState = .skipped
        notifyEvent(.skipped)
        
        if let config = rewardConfig {
            Logger.info("💡 奖励信息 - 广告位: \(adSlotID), 奖励: \(String(describing: config.points)) \(config.rewardDescription ?? "积分")")
        }
    }
    
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        if let error = error {
            Logger.info("❌ 广告播放失败 - 广告位: \(adSlotID), 错误: \(error.localizedDescription)")
            currentState = .playFailed
            notifyEvent(.playFailed(error))
        } else {
            Logger.info("✅ 广告播放完成 - 广告位: \(adSlotID)")
            currentState = .playFinished
            notifyEvent(.playFinished)
        }
    }
    
    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        Logger.info("🎁 奖励发放成功 - 广告位: \(adSlotID), 验证: \(verify)")
        
        if let config = rewardConfig {
            Logger.info("💰 获得奖励 - 广告位: \(adSlotID), 奖励: \(String(describing: config.points)) \(config.rewardDescription ?? "积分")")
        }
        
        currentState = .rewardSuccess
        notifyEvent(.rewardSuccess(verified: verify))
    }
    
    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        Logger.info("❌ 奖励发放失败 - 广告位: \(adSlotID), 错误: \(error?.localizedDescription ?? "未知错误")")
        currentState = .rewardFailed
        notifyEvent(.rewardFailed(error))
    }
    
    /// 广告关闭 - 关键修改：触发自动移除
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        Logger.info("🚪 广告关闭 - 广告位: \(adSlotID)")
        currentState = .closed
        notifyEvent(.closed)
        
        // 清理资源
        cleanupCurrentAd()
        destroyAdObject()
        
        // 延迟触发自动移除，确保所有回调都执行完毕
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.triggerAutoRemove()
        }
    }
}
