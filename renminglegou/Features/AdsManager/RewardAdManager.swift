//
//  RewardAdManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import BUAdSDK

// MARK: - 激励广告状态
enum RewardAdState {
    case loading      // 加载中
    case loaded       // 已加载
    case showing      // 展示中
    case closed       // 已关闭
    case failed       // 失败
}

// MARK: - 激励广告回调
protocol RewardAdManagerDelegate: AnyObject {
    /// 广告加载成功
    func rewardAdDidLoad()
    /// 广告加载失败
    func rewardAdDidFailToLoad(error: Error?)
    /// 广告展示成功
    func rewardAdDidShow()
    /// 广告展示失败
    func rewardAdDidFailToShow(error: Error)
    /// 广告被点击
    func rewardAdDidClick()
    /// 广告被关闭
    func rewardAdDidClose()
    /// 广告奖励发放成功
    func rewardAdDidRewardUser(verified: Bool)
    /// 广告奖励发放失败
    func rewardAdDidFailToReward(error: Error?)
    /// 广告视频播放完成
    func rewardAdDidFinishPlaying(error: Error?)
}

// MARK: - 激励广告管理器
class RewardAdManager: NSObject {
    
    // MARK: - 单例
    static let shared = RewardAdManager()
    
    // MARK: - 属性
    weak var delegate: RewardAdManagerDelegate?
    
    private var rewardedVideoAd: BUNativeExpressRewardedVideoAd?
    private var adSlotID: String = "103510224" // 默认广告位ID
    private var currentState: RewardAdState = .closed
    private var isAutoShowAfterLoad: Bool = false
    private var pendingViewController: UIViewController?
    
    // MARK: - 初始化
    private override init() {
        super.init()
    }
    
    // MARK: - 公开方法
    
    /// 配置广告位ID
    /// - Parameter slotID: 广告位ID
    func configure(slotID: String) {
        self.adSlotID = slotID
    }
    
    /// 预加载广告
    func preloadAd() {
        guard currentState != .loading else {
            print("广告正在加载中...")
            return
        }
        
        loadAd()
    }
    
    /// 展示广告
    /// - Parameters:
    ///   - viewController: 用于展示广告的视图控制器
    ///   - autoLoad: 如果广告未加载，是否自动加载
    func showAd(from viewController: UIViewController, autoLoad: Bool = true) {
        switch currentState {
        case .loaded:
            // 广告已加载，直接展示
            rewardedVideoAd?.show(fromRootViewController: viewController)
            currentState = .showing
            
        case .loading:
            // 广告加载中，等待加载完成后自动展示
            isAutoShowAfterLoad = true
            pendingViewController = viewController
            print("广告加载中，将在加载完成后自动展示")
            
        case .closed, .failed:
            if autoLoad {
                // 广告未加载，自动加载并在完成后展示
                isAutoShowAfterLoad = true
                pendingViewController = viewController
                loadAd()
            } else {
                print("广告未加载，请先调用 preloadAd()")
                delegate?.rewardAdDidFailToShow(error: NSError(domain: "RewardAdManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "广告未加载"]))
            }
            
        case .showing:
            print("广告正在展示中...")
        }
    }
    
    /// 检查广告是否已加载
    var isAdLoaded: Bool {
        return currentState == .loaded
    }
    
    /// 当前广告状态
    var adState: RewardAdState {
        return currentState
    }
    
    /// 销毁广告
    func destroyAd() {
        rewardedVideoAd?.delegate = nil
        rewardedVideoAd = nil
        currentState = .closed
        isAutoShowAfterLoad = false
        pendingViewController = nil
    }
}

// MARK: - 私有方法
private extension RewardAdManager {
    
    func loadAd() {
        currentState = .loading
        
        let slot = BUAdSlot()
        slot.id = adSlotID
        slot.mediation.mutedIfCan = false
        
        let rewardedVideoModel = BURewardedVideoModel()
        let userId = "ios_\(UserModel.shared.userId)_\(Int64(Date().timeIntervalSince1970 * 1000))"
        rewardedVideoModel.userId = userId
        let rewardedVideoAd = BUNativeExpressRewardedVideoAd(slot: slot, rewardedVideoModel: rewardedVideoModel)
        rewardedVideoAd.delegate = self
        
        // 设置竖屏展示
        rewardedVideoAd.mediation?.addParam(NSNumber(value: 0), withKey: "show_direction")
        
        self.rewardedVideoAd = rewardedVideoAd
        self.rewardedVideoAd?.loadData()
    }
    
    func handleLoadSuccess() {
        currentState = .loaded
        delegate?.rewardAdDidLoad()
        
        // 如果设置了自动展示，则立即展示
        if isAutoShowAfterLoad, let viewController = pendingViewController {
            isAutoShowAfterLoad = false
            pendingViewController = nil
            showAd(from: viewController, autoLoad: false)
        }
    }
    
    func handleLoadFailed(_ error: Error?) {
        currentState = .failed
        isAutoShowAfterLoad = false
        pendingViewController = nil
        delegate?.rewardAdDidFailToLoad(error: error)
    }
}

// MARK: - BUMNativeExpressRewardedVideoAdDelegate
extension RewardAdManager: BUMNativeExpressRewardedVideoAdDelegate {
    
    /// 广告加载成功
    func nativeExpressRewardedVideoAdDidLoad(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告加载成功")
        handleLoadSuccess()
    }
    
    /// 广告加载失败
    func nativeExpressRewardedVideoAd(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        print("激励广告加载失败: \(error?.localizedDescription ?? "未知错误")")
        handleLoadFailed(error)
    }
    
    /// 广告素材加载完成
    func nativeExpressRewardedVideoAdDidDownLoadVideo(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告素材加载完成")
    }
    
    /// 广告展示失败
    func nativeExpressRewardedVideoAdDidShowFailed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error) {
        print("激励广告展示失败: \(error.localizedDescription)")
        currentState = .failed
        delegate?.rewardAdDidFailToShow(error: error)
    }
    
    /// 广告已经展示
    func nativeExpressRewardedVideoAdDidVisible(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告开始展示")
        currentState = .showing
        delegate?.rewardAdDidShow()
        
        // 获取广告信息（可选）
        if let info = rewardedVideoAd.mediation?.getShowEcpmInfo() {
            print("广告信息 - ecpm: \(info.ecpm ?? "None"), platform: \(info.adnName)")
        }
    }
    
    /// 广告已经关闭
    func nativeExpressRewardedVideoAdDidClose(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告关闭")
        currentState = .closed
        delegate?.rewardAdDidClose()
        
        // 广告关闭后，可以预加载下一个广告
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.preloadAd()
        }
    }
    
    /// 广告被点击
    func nativeExpressRewardedVideoAdDidClick(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告被点击")
        delegate?.rewardAdDidClick()
    }
    
    /// 广告被点击跳过
    func nativeExpressRewardedVideoAdDidClickSkip(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd) {
        print("激励广告被跳过")
    }
    
    /// 广告视频播放完成
    func nativeExpressRewardedVideoAdDidPlayFinish(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, didFailWithError error: Error?) {
        print("激励广告播放完成")
        delegate?.rewardAdDidFinishPlaying(error: error)
    }
    
    /// 广告奖励下发成功
    func nativeExpressRewardedVideoAdServerRewardDidSucceed(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, verify: Bool) {
        print("激励广告奖励下发成功 - 验证状态: \(verify)")
        delegate?.rewardAdDidRewardUser(verified: verify)
        
        if verify {
            // 验证通过，从 rewardedVideoModel 读取奖励信息
            // let rewardInfo = rewardedVideoAd.rewardedVideoModel
            print("奖励验证通过，可以发放奖励")
        } else {
            print("奖励验证未通过")
        }
    }
    
    /// 广告奖励下发失败
    func nativeExpressRewardedVideoAdServerRewardDidFail(_ rewardedVideoAd: BUNativeExpressRewardedVideoAd, error: Error?) {
        print("激励广告奖励下发失败: \(error?.localizedDescription ?? "未知错误")")
        delegate?.rewardAdDidFailToReward(error: error)
    }
}
