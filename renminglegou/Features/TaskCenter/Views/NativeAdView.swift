//
//  NativeAdView.swift
//  renminglegou
//
//  Created by Developer on 8/31/25.
//

import SwiftUI
import UIKit
import BUAdSDK

// MARK: - 自定义传递视图
// 简化的容器视图，不干预SDK的点击机制
class PassThroughView: UIView {
    // 使用默认的hitTest实现，不做任何干预
}

// MARK: - SwiftUI 包装器
struct NativeAdView: UIViewRepresentable {
    private let defaultSlotId: String = "103509927"
    @State private var adHeight: CGFloat = 160
    
    // 高度变化回调
    private let onHeightChanged: ((CGFloat) -> Void)?
    
    init(onHeightChanged: ((CGFloat) -> Void)? = nil) {
        self.onHeightChanged = onHeightChanged
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = PassThroughView()  // 使用自定义的传递视图
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        // 确保容器可以响应手势
        containerView.isUserInteractionEnabled = true
        
        let slotId = AdSlotManager.shared.getCurrentFeedAdSlotId() ?? defaultSlotId
        // 创建广告管理器
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.loadAd(in: containerView, slotId: slotId)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // SwiftUI更新时调用
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 更新高度
    private func notifyHeightChanged(_ newHeight: CGFloat) {
        if newHeight != adHeight && newHeight > 0 {
            DispatchQueue.main.async {
                self.onHeightChanged?(newHeight)
            }
            Logger.info("信息流广告高度更新: \(newHeight)", category: .adSlot)
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, BUMNativeAdsManagerDelegate, BUMNativeAdDelegate, BUCustomEventProtocol {
        var parent: NativeAdView
        var currentAd: BUNativeAd?
        private var adManager: BUNativeAdsManager?
        private weak var containerView: UIView?
        private var heightConstraint: NSLayoutConstraint?
        private var retryCount = 0
        private let maxRetryCount = 3
        
        init(_ parent: NativeAdView) {
            self.parent = parent
        }
        
        func loadAd(in containerView: UIView, slotId: String) {
            self.containerView = containerView
            
            Logger.info("开始加载信息流广告, SlotID: \(slotId)", category: .adSlot)
            
            // 销毁上次广告对象
            adManager?.mediation?.destory()
            currentAd = nil
            
            // 创建广告位配置
            let slot = BUAdSlot()
            slot.id = slotId
            slot.adType = BUAdSlotAdType.feed
            slot.position = BUAdSlotPosition.feed
            
            // 设置广告位尺寸 - 使用具体宽度
            let screenWidth = DeviceConsts.screenWidth - 32  // 减去左右边距
            slot.adSize = CGSize(width: screenWidth, height: 0)
            slot.mediation.mutedIfCan = false
            
            Logger.info("设置广告位尺寸: \(screenWidth) x auto", category: .adSlot)
            
            // 创建广告管理器
            let manager = BUNativeAdsManager(slot: slot)
            if let rootVC = UIUtils.findViewController() {
                manager.mediation?.rootViewController = rootVC
            }
            
            manager.delegate = self
            self.adManager = manager
            manager.loadAdData(withCount: 1)
        }
        

        
        private func setupAdView(adView: UIView, in containerView: UIView) {
            // 清除之前的广告视图和约束
            containerView.subviews.forEach { $0.removeFromSuperview() }
            heightConstraint = nil
            
            // 添加新的广告视图
            containerView.addSubview(adView)
            adView.translatesAutoresizingMaskIntoConstraints = false
            
            // 如果是模板广告，确保子视图也可以响应手势
            for subview in adView.subviews {
                subview.isUserInteractionEnabled = true
            }
            
            Logger.info("使用PassThroughView确保点击事件正确传递", category: .adSlot)
            
            // 设置完整约束
            let constraints = [
                adView.topAnchor.constraint(equalTo: containerView.topAnchor),
                adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            
            // 为容器设置初始最小高度约束
            heightConstraint = containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
            heightConstraint?.priority = UILayoutPriority(999)
            heightConstraint?.isActive = true
            
            Logger.info("设置初始容器约束: 最小高度100px", category: .adSlot)
            
            Logger.info("广告视图约束设置完成，广告视图类型: \(type(of: adView))", category: .adSlot)
            Logger.info("广告视图 frame: \(adView.frame)", category: .adSlot)
            Logger.info("广告视图 bounds: \(adView.bounds)", category: .adSlot)
            Logger.info("广告视图子视图数量: \(adView.subviews.count)", category: .adSlot)
            Logger.info("容器视图交互状态: \(containerView.isUserInteractionEnabled)", category: .adSlot)
            Logger.info("广告视图交互状态: \(adView.isUserInteractionEnabled)", category: .adSlot)
        }
        
        // MARK: - BUMNativeAdsManagerDelegate
        
        func nativeAdsManagerSuccess(toLoad adsManager: BUNativeAdsManager, nativeAds nativeAdDataArray: [BUNativeAd]?) {
            guard let adList = nativeAdDataArray,
                  let firstAd = adList.first,
                  let containerView = self.containerView else {
                Logger.error("信息流广告数据为空或容器视图无效", category: .adSlot)
                return
            }
            
            self.currentAd = firstAd
            Logger.success("信息流广告加载成功，广告数量: \(adList.count)", category: .adSlot)
            
            // 设置广告属性
            if let rootVC = UIUtils.findViewController() {
                firstAd.rootViewController = rootVC
                Logger.info("设置广告 rootViewController: \(rootVC)", category: .adSlot)
            } else {
                Logger.warning("未找到 rootViewController", category: .adSlot)
            }
            firstAd.delegate = self
            
            // 设置广告管理器的 rootViewController
            if let rootVC = UIUtils.findViewController() {
                adsManager.mediation?.rootViewController = rootVC
            }
            
            DispatchQueue.main.async {
                // 检查是否为模板广告
                if let canvasView = firstAd.mediation?.canvasView {
                    Logger.info("检测到模板广告，添加 canvasView", category: .adSlot)
                    self.setupAdView(adView: canvasView, in: containerView)
                    
                    // 主动触发模板渲染（如果需要）
                    if let isExpressAd = firstAd.mediation?.isExpressAd, isExpressAd {
                        // 有些情况下需要主动调用 render 方法
                        firstAd.mediation?.render()  // 取消注释如果需要
                    }
                    
                    // 不再在这里获取高度，等待渲染成功回调
                    Logger.info("等待模板广告渲染完成...", category: .adSlot)
                    
                } else {
                    Logger.info("检测到自渲染广告，创建自定义视图", category: .adSlot)
                }
            }
        }
        
        func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
            Logger.error("信息流广告加载失败: \(error?.localizedDescription ?? "未知错误")", category: .adSlot)
        }
        
        // MARK: - BUMNativeAdDelegate
        
        func nativeAdDidBecomeVisible(_ nativeAd: BUNativeAd) {
            Logger.success("信息流广告展示成功", category: .adSlot)
            
            // 当广告真正展示时，再次检查高度
            if let canvasView = nativeAd.mediation?.canvasView {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    // 只有当前高度还是初始值时才重新检查
                    if canvasView.frame.height <= 100 {
                        Logger.info("广告展示后重新检查高度", category: .adSlot)
                        self.retryCount = 0
                        self.getAccurateAdHeight(canvasView: canvasView)
                    }
                }
            }
        }
        
        func nativeAdDidClick(_ nativeAd: BUNativeAd, with view: UIView?) {
            Logger.success("信息流广告被点击✅", category: .adSlot)
            Logger.info("点击的视图: \(view?.description ?? "nil")", category: .adSlot)
        }
        
        func nativeAd(_ nativeAd: BUNativeAd?, dislikeWithReason filterWords: [BUDislikeWords]?) {
            Logger.info("用户负反馈，移除广告", category: .adSlot)
            DispatchQueue.main.async {
                self.containerView?.subviews.forEach { $0.removeFromSuperview() }
                self.updateContainerHeight(0)
            }
        }
        
        // 模板广告渲染成功回调 - 优化版
        func nativeAdExpressViewRenderSuccess(_ nativeAd: BUNativeAd) {
            Logger.success("模板广告渲染成功", category: .adSlot)
            
            guard let canvasView = nativeAd.mediation?.canvasView else {
                Logger.error("无法获取canvasView", category: .adSlot)
                return
            }
            
            DispatchQueue.main.async {
                // 确保广告视图已经添加
                if canvasView.superview != self.containerView {
                    self.setupAdView(adView: canvasView, in: self.containerView!)
                }
                
                // 重置重试计数
                self.retryCount = 0
                
                // 等待渲染完全完成后获取高度
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.getAccurateAdHeight(canvasView: canvasView)
                }
            }
        }
        
        func nativeAdExpressViewRenderFail(_ nativeAd: BUNativeAd, error: Error?) {
            Logger.error("模板广告渲染失败: \(error?.localizedDescription ?? "未知错误")", category: .adSlot)
        }
        
        // MARK: - Private Methods
        
        private func selectBestHeight(bounds: CGFloat, frame: CGFloat, intrinsic: CGFloat) -> CGFloat {
            let heights = [bounds, frame, intrinsic]
            
            // 过滤掉无效值
            let validHeights = heights.filter { height in
                return height > 0 && 
                       height != CGFloat.greatestFiniteMagnitude && 
                       height != CGFloat.infinity &&
                       !height.isNaN &&
                       height < 1000  // 排除异常大的值
            }
            
            if validHeights.isEmpty {
                return 0
            }
            
            // 优先选择最稳定的高度值（frame > bounds > intrinsic）
            if frame > 0 && frame < 1000 && !frame.isNaN {
                return frame
            }
            
            if bounds > 0 && bounds < 1000 && !bounds.isNaN {
                return bounds
            }
            
            if intrinsic > 0 && intrinsic < 1000 && !intrinsic.isNaN {
                return intrinsic
            }
            
            return validHeights.first ?? 0
        }
        
        private func updateContainerHeight(_ newHeight: CGFloat) {
            guard let containerView = self.containerView, newHeight > 0 else { return }
            
            DispatchQueue.main.async {
                // 移除旧的高度约束
                self.heightConstraint?.isActive = false
                
                // 创建新的精确高度约束
                self.heightConstraint = containerView.heightAnchor.constraint(equalToConstant: newHeight)
                self.heightConstraint?.priority = UILayoutPriority(1000)
                self.heightConstraint?.isActive = true
                
                // 触发布局更新
                containerView.superview?.setNeedsLayout()
                containerView.superview?.layoutIfNeeded()
                
                // 通知 SwiftUI 更新
                self.parent.notifyHeightChanged(newHeight)
                
                Logger.success("容器高度已精确更新为: \(newHeight)", category: .adSlot)
            }
        }
        
        private func handleCustomRenderAd(ad: BUNativeAd) {
            Logger.info("处理自渲染广告，标题: \(ad.data?.adTitle ?? "无标题")", category: .adSlot)
            // 自渲染广告的处理逻辑
            // 这里需要根据具体需求实现自定义渲染
            updateContainerHeight(160) // 自渲染广告使用默认高度
        }
        
        // MARK: - 新增高度获取方法
        
        private func getAccurateAdHeight(canvasView: UIView) {
            // 强制完成布局
            canvasView.setNeedsLayout()
            canvasView.layoutIfNeeded()
            canvasView.superview?.setNeedsLayout()
            canvasView.superview?.layoutIfNeeded()
            
            // 检查子视图情况
            Logger.info("canvasView子视图数量: \(canvasView.subviews.count)", category: .adSlot)
            for (index, subview) in canvasView.subviews.enumerated() {
                Logger.info("  子视图\(index): \(type(of: subview)), frame: \(subview.frame)", category: .adSlot)
            }
            
            // 延长等待时间，确保广告完全渲染
            let waitTime = self.retryCount == 0 ? 0.5 : 1.0  // 第一次等待更长
            DispatchQueue.main.asyncAfter(deadline: .now() + waitTime) {
                // 再次强制布局
                canvasView.setNeedsLayout()
                canvasView.layoutIfNeeded()
                
                // 关键修复：检查并修复canvasView的宽度问题
                if canvasView.frame.width == 0 {
                    Logger.warning("canvasView宽度为0，需要修复宽度", category: .adSlot)
                    let containerWidth = self.containerView?.frame.width ?? 388
                    
                    // 保存原始的子视图高度
                    let originalSubviewHeight = canvasView.subviews.first?.frame.height ?? canvasView.frame.height
                    Logger.info("原始子视图高度: \(originalSubviewHeight)", category: .adSlot)
                    
                    // 只修改宽度，保持高度不变
                    canvasView.frame = CGRect(
                        x: canvasView.frame.origin.x,
                        y: canvasView.frame.origin.y,
                        width: containerWidth,
                        height: max(canvasView.frame.height, originalSubviewHeight)
                    )
                    
                    Logger.info("修复后的canvasView frame: \(canvasView.frame)", category: .adSlot)
                    
                    // 重新布局子视图
                    canvasView.setNeedsLayout()
                    canvasView.layoutIfNeeded()
                    
                    // 检查修复后的子视图高度
                    let newSubviewHeight = canvasView.subviews.first?.frame.height ?? 0
                    Logger.info("修复后子视图高度: \(newSubviewHeight)", category: .adSlot)
                    
                    // 如果子视图高度被压缩了，直接返回原始高度
                    if newSubviewHeight < originalSubviewHeight && originalSubviewHeight > 100 {
                        Logger.success("使用原始子视图高度: \(originalSubviewHeight)", category: .adSlot)
                        self.updateContainerHeight(originalSubviewHeight)
                        return
                    }
                }
                
                let bounds = canvasView.bounds.height
                let frame = canvasView.frame.height  
                let intrinsic = canvasView.intrinsicContentSize.height
                
                Logger.info("第\(self.retryCount + 1)次获取高度:", category: .adSlot)
                Logger.info("  canvasView bounds: \(canvasView.bounds)", category: .adSlot)
                Logger.info("  canvasView frame: \(canvasView.frame)", category: .adSlot)
                Logger.info("  bounds.height: \(bounds)", category: .adSlot)
                Logger.info("  frame.height: \(frame)", category: .adSlot)
                Logger.info("  intrinsic.height: \(intrinsic)", category: .adSlot)
                
                // 检查子视图的实际高度
                Logger.info("重新检查子视图高度:", category: .adSlot)
                for (index, subview) in canvasView.subviews.enumerated() {
                    Logger.info("  子视图\(index): \(type(of: subview)), frame: \(subview.frame)", category: .adSlot)
                }
                
                let subviewsTotalHeight = canvasView.subviews.reduce(0) { result, subview in
                    return result + subview.frame.height
                }
                Logger.info("  子视图总高度: \(subviewsTotalHeight)", category: .adSlot)
                
                // 特殊处理：如果子视图高度不对，使用最大的子视图高度
                let maxSubviewHeight = canvasView.subviews.max(by: { $0.frame.height < $1.frame.height })?.frame.height ?? 0
                Logger.info("  最大子视图高度: \(maxSubviewHeight)", category: .adSlot)
                
                let actualSubviewHeight = max(subviewsTotalHeight, maxSubviewHeight)
                Logger.info("  实际使用的子视图高度: \(actualSubviewHeight)", category: .adSlot)
                
                // 如果canvasView高度是约束初始值，但子视图有真实内容高度，优先使用子视图高度
                let finalHeight: CGFloat
                if (bounds <= 100 || frame <= 100) && actualSubviewHeight > 100 {
                    finalHeight = actualSubviewHeight
                    Logger.success("使用子视图高度: \(finalHeight)", category: .adSlot)
                } else {
                    let selectBestResult = self.selectBestHeight(
                        bounds: bounds,
                        frame: frame,
                        intrinsic: intrinsic
                    )
                    
                    // 如果selectBestHeight结果也不理想，但有子视图高度，使用子视图高度
                    if selectBestResult <= 100 && actualSubviewHeight > 100 {
                        finalHeight = actualSubviewHeight
                        Logger.success("回退使用子视图高度: \(finalHeight)", category: .adSlot)
                    } else {
                        finalHeight = selectBestResult
                        Logger.info("使用selectBestHeight结果: \(finalHeight)", category: .adSlot)
                    }
                }
                
                if finalHeight > 50 {  // 提高阈值，50px太小了
                    Logger.success("获取到有效高度: \(finalHeight)", category: .adSlot)
                    self.updateContainerHeight(finalHeight)
                    
                } else if self.retryCount < self.maxRetryCount {
                    self.retryCount += 1
                    Logger.warning("高度获取失败(\(finalHeight)px)，第\(self.retryCount)次重试", category: .adSlot)
                    
                    // 延长等待时间重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.getAccurateAdHeight(canvasView: canvasView)
                    }
                } else {
                    Logger.error("多次重试失败，使用默认高度", category: .adSlot)
                    self.updateContainerHeight(180) // 使用更合理的默认高度
                }
            }
        }
        
        // MARK: - 交互辅助方法
        
        private func enableInteractionRecursively(view: UIView) {
            view.isUserInteractionEnabled = true
            for subview in view.subviews {
                enableInteractionRecursively(view: subview)
            }
            Logger.debug("设置视图交互: \(type(of: view)) - enabled: \(view.isUserInteractionEnabled)", category: .adSlot)
        }
        
        // MARK: - 其他BUMNativeAdDelegate方法
        
        func nativeAdWillPresentFullScreenModal(_ nativeAd: BUNativeAd) {
            Logger.success("信息流广告即将展示详情页✅", category: .adSlot)
        }
        
        func nativeAdDidDismissFullScreenModal(_ nativeAd: BUNativeAd) {
            Logger.info("信息流广告详情页已关闭", category: .adSlot)
        }
        
        func nativeAdWillLeaveApplication(_ nativeAd: BUNativeAd) {
            Logger.success("信息流广告即将跳转到其他应用✅", category: .adSlot)
        }
        
        // MARK: - 视频相关回调
        func nativeAdVideo(_ nativeAd: BUNativeAd?, stateDidChanged playerState: BUPlayerPlayState) {
            switch playerState {
            case .statePlaying:
                Logger.debug("视频开始播放", category: .adSlot)
            case .statePause:
                Logger.debug("视频暂停", category: .adSlot)
            case .stateStopped:
                Logger.debug("视频停止", category: .adSlot)
            case .stateFailed:
                Logger.debug("视频播放失败", category: .adSlot)
            default:
                Logger.debug("视频播放状态变更: \(playerState.rawValue)", category: .adSlot)
            }
        }
        
        func nativeAdVideoDidClick(_ nativeAd: BUNativeAd?) {
            Logger.info("视频被点击", category: .adSlot)
        }
        
        func nativeAdVideoDidPlayFinish(_ nativeAd: BUNativeAd?) {
            Logger.info("视频播放完成", category: .adSlot)
        }
        
        func nativeAdShakeViewDidDismiss(_ nativeAd: BUNativeAd?) {
            Logger.info("摇一摇提示view消失", category: .adSlot)
        }
        
        func nativeAdVideo(_ nativeAdView: BUNativeAd?, rewardDidCountDown countDown: Int) {
            Logger.debug("激励视频倒计时: \(countDown)", category: .adSlot)
        }
        
        // MARK: - BUCustomEventProtocol (如果需要的话)
        func customEvent(withType type: Int, params: [AnyHashable : Any]?) {
            Logger.debug("自定义事件 type: \(type), params: \(params?.description ?? "nil")", category: .adSlot)
        }
    }
}

