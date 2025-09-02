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
    
    // MARK: - 属性
    private var rewardedVideoAd: BUNativeExpressRewardedVideoAd?
    private let adSlotID: String
    private var currentState: RewardAdState = .initial
    
    // 回调存储
    private var eventCallback: RewardAdEventCallback?
    private var loadCallbacks: [RewardAdLoadCallback] = []
    private var pendingShowRequest: (UIViewController, RewardAdEventCallback?, RewardAdShowCallback?)?
    
    // 超时管理
    private var loadingTimer: Timer?
    private let loadTimeout: TimeInterval = 15.0 // 15秒超时
    
    // 配置
    var autoReloadAfterClose: Bool = true
    
    // MARK: - 初始化
    init(slotID: String) {
        self.adSlotID = slotID
        super.init()
    }
    
    // MARK: - 公开方法
    
    /// 设置事件回调（监听所有事件）
    /// - Parameter callback: 事件回调
    func setEventCallback(_ callback: RewardAdEventCallback?) {
        self.eventCallback = callback
    }
    
    /// 预加载广告
    /// - Parameter completion: 加载结果回调
    func preloadAd(completion: RewardAdLoadCallback? = nil) {
        
        if let completion = completion {
            loadCallbacks.append(completion)
        }
        
        guard currentState != .loading else {
            print("广告位 \(adSlotID) 正在加载中...")
            return
        }
        
        if isReady {
            print("广告位 \(adSlotID) 已准备就绪")
            executeLoadCallbacks(.success(()))
            return
        }
        
        startLoading()
    }
    
    /// 展示广告
    /// - Parameters:
    ///   - viewController: 展示控制器
    ///   - eventCallback: 事件回调（可选，如果设置会覆盖全局回调）
    ///   - completion: 展示结果回调（成功表示开始展示，不代表奖励获得）
    ///   - autoLoad: 是否自动加载
    func showAd(from viewController: UIViewController,
                eventCallback: RewardAdEventCallback? = nil,
                completion: RewardAdShowCallback? = nil,
                autoLoad: Bool = true) {
        
        // 临时设置事件回调
        if let eventCallback = eventCallback {
            self.eventCallback = eventCallback
        }
        
        switch currentState {
        case .loaded, .videoDownloaded:
            performShow(from: viewController, completion: completion)
            
        case .loading:
            print("广告正在加载中，加入等待队列")
            pendingShowRequest = (viewController, eventCallback, completion)
            
        case .showing:
            let error = NSError(domain: "RewardAdManager", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "广告正在展示"])
            completion?(.failure(error))
            
        default:
            if autoLoad {
                print("广告未准备就绪，开始自动加载")
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
    
    // MARK: - 销毁方法
    func destroyAd() {
        cleanupCurrentAd()
        currentState = .initial
        eventCallback = nil
        loadCallbacks.removeAll()
        pendingShowRequest = nil
    }
    
    // MARK: - 私有方法
    
    private func startLoading() {
        // 先清理旧的广告对象
        cleanupCurrentAd()
        
        currentState = .loading
        notifyEvent(.loadStarted)
        
        // 设置加载超时定时器
        loadingTimer = Timer.scheduledTimer(withTimeInterval: loadTimeout, repeats: false) { [weak self] _ in
            self?.handleLoadTimeout()
        }
        
        let slot = BUAdSlot()
        slot.id = adSlotID
        slot.mediation.mutedIfCan = false
        
        let rewardedVideoModel = BURewardedVideoModel()
        let userId = "ios_\(UserModel.shared.userId)_\(Int64(Date().timeIntervalSince1970 * 1000))"
        rewardedVideoModel.userId = userId
        
        let rewardedVideoAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: rewardedVideoModel)
        rewardedVideoAd.delegate = self
        rewardedVideoAd.mediation?.addParam(NSNumber(value: 0), withKey: "show_direction")
        
        self.rewardedVideoAd = rewardedVideoAd
        self.rewardedVideoAd?.loadData()
        
        print("开始加载广告 - 广告位: \(adSlotID)")
    }
    
    private func cleanupCurrentAd() {
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        rewardedVideoAd?.delegate = nil
        rewardedVideoAd = nil
    }
    
    private func handleLoadTimeout() {
        print("⚠️ 广告加载超时 - 广告位: \(adSlotID)")
        let error = NSError(domain: "RewardAdManager", code: -100,
                          userInfo: [NSLocalizedDescriptionKey: "广告加载超时"])
        
        currentState = .loadFailed
        notifyEvent(.loadFailed(error))
        executeLoadCallbacks(.failure(error))
        
        // 处理等待中的展示请求
        if let (_, _, completion) = pendingShowRequest {
            pendingShowRequest = nil
            completion?(.failure(error))
        }
        
        cleanupCurrentAd()
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
        
        // 注意：这里的 completion 表示开始展示，不是展示成功
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
            print("📺 广告事件 - 广告位: \(self.adSlotID), 事件: \(event.description)")
        }
    }
}

// MARK: - SDK代理实现
extension SingleRewardAdManager: BUMNativeExpressRewardedVideoAdDelegate {
    
    /// 广告加载成功
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        // 清除超时定时器
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        print("✅ 广告加载成功 - 广告位: \(adSlotID)")
        currentState = .loaded
        notifyEvent(.loadSuccess)
        executeLoadCallbacks(.success(()))
        handlePendingShow()
    }
    
    /// 广告加载失败
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        // 清除超时定时器
        loadingTimer?.invalidate()
        loadingTimer = nil
        
        print("❌ 广告加载失败 - 广告位: \(adSlotID), 错误: \(error?.localizedDescription ?? "未知错误")")
        currentState = .loadFailed
        let adError = error ?? NSError(domain: "RewardAdManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "广告加载失败"])
        
        notifyEvent(.loadFailed(adError))
        executeLoadCallbacks(.failure(adError))
        
        if let (_, _, completion) = pendingShowRequest {
            pendingShowRequest = nil
            completion?(.failure(adError))
        }
        
        cleanupCurrentAd()
    }
    
    /// 广告素材下载完成
    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("📥 广告素材下载完成 - 广告位: \(adSlotID)")
        currentState = .videoDownloaded
        notifyEvent(.videoDownloaded)
    }
    
    /// 广告展示成功
    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("👀 广告展示成功 - 广告位: \(adSlotID)")
        notifyEvent(.showSuccess)
        
        if let info = rewardedVideoAd.mediation?.getShowEcpmInfo() {
            print("💰 广告信息 - 广告位: \(adSlotID), ecpm: \(info.ecpm ?? "None"), platform: \(info.adnName)")
        }
    }
    
    /// 广告展示失败
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
        print("❌ 广告展示失败 - 广告位: \(adSlotID), 错误: \(error.localizedDescription)")
        currentState = .showFailed
        notifyEvent(.showFailed(error))
    }
    
    /// 广告被点击
    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("👆 广告被点击 - 广告位: \(adSlotID)")
        currentState = .clicked
        notifyEvent(.clicked)
    }
    
    /// 广告被跳过
    func nativeExpressRewardedVideoAdDidClickSkip(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("⏭️ 广告被跳过 - 广告位: \(adSlotID)")
        currentState = .skipped
        notifyEvent(.skipped)
    }
    
    /// 广告播放完成/失败
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        if let error = error {
            print("❌ 广告播放失败 - 广告位: \(adSlotID), 错误: \(error.localizedDescription)")
            currentState = .playFailed
            notifyEvent(.playFailed(error))
        } else {
            print("✅ 广告播放完成 - 广告位: \(adSlotID)")
            currentState = .playFinished
            notifyEvent(.playFinished)
        }
    }
    
    /// 广告奖励发放成功
    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        print("🎁 奖励发放成功 - 广告位: \(adSlotID), 验证: \(verify)")
        currentState = .rewardSuccess
        notifyEvent(.rewardSuccess(verified: verify))
    }
    
    /// 广告奖励发放失败
    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        print("❌ 奖励发放失败 - 广告位: \(adSlotID), 错误: \(error?.localizedDescription ?? "未知错误")")
        currentState = .rewardFailed
        notifyEvent(.rewardFailed(error))
    }
    
    /// 广告关闭
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("🚪 广告关闭 - 广告位: \(adSlotID)")
        currentState = .closed
        notifyEvent(.closed)
        
        // 清理广告对象
        cleanupCurrentAd()
        
        if autoReloadAfterClose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                print("🔄 自动重新加载广告 - 广告位: \(self.adSlotID)")
                self.preloadAd()
            }
        }
    }
}
