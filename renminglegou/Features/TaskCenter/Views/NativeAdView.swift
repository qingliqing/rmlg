//
//  NativeAdView.swift
//  renminglegou
//
//  Created by Developer on 8/31/25.
//

import SwiftUI
import UIKit
import BUAdSDK

// MARK: - SwiftUI 包装器
struct NativeAdView: UIViewRepresentable {
    let slotId: String
    @State private var adHeight: CGFloat = 160
    
    // 高度变化回调
    private let onHeightChanged: ((CGFloat) -> Void)?
    
    init(slotId: String, onHeightChanged: ((CGFloat) -> Void)? = nil) {
        self.slotId = slotId
        self.onHeightChanged = onHeightChanged
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = .clear
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
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
    
    // 内部方法：更新高度
    private mutating func updateHeight(_ newHeight: CGFloat) {
        if newHeight != adHeight && newHeight > 0 {
            adHeight = newHeight
            onHeightChanged?(newHeight)
            Logger.info("信息流广告高度更新: \(newHeight)", category: .adSlot)
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, BUMNativeAdsManagerDelegate, BUMNativeAdDelegate, BUCustomEventProtocol {
        var parent: NativeAdView
        private var currentAd: BUNativeAd?
        private var adManager: BUNativeAdsManager?
        private weak var containerView: UIView?
        private var heightConstraint: NSLayoutConstraint?
        
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
            
            // 设置完整约束
            let constraints = [
                adView.topAnchor.constraint(equalTo: containerView.topAnchor),
                adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                adView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ]
            NSLayoutConstraint.activate(constraints)
            
            // 为容器设置初始高度约束
            heightConstraint = containerView.heightAnchor.constraint(equalToConstant: 160)
            heightConstraint?.isActive = true
            
            Logger.info("广告视图约束设置完成", category: .adSlot)
        }
        
        // MARK: - BUMNativeAdsManagerDelegate
        
        func nativeAdsManagerSuccess(toLoad adsManager: BUNativeAdsManager, nativeAds nativeAdDataArray: [BUNativeAd]?) {
            guard let adList = nativeAdDataArray,
                  let firstAd = adList.first else {
                Logger.error("信息流广告数据为空或容器视图无效", category: .adSlot)
                return
            }
            
            self.currentAd = firstAd
            Logger.success("信息流广告加载成功，广告数量: \(adList.count)", category: .adSlot)
            
            // 设置广告属性
            if let rootVC = UIUtils.findViewController() {
                firstAd.rootViewController = rootVC
            }
            firstAd.delegate = self
            
            // 添加canvasView到容器
            if let canvasView = firstAd.mediation?.canvasView {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    
                    // 优先拿 frame.height
                    let finalHeight = canvasView.frame.height
                    
                    if finalHeight > 0 {
                        Logger.success("广告最终高度: \(finalHeight)", category: .adSlot)
                        self.updateContainerHeight(finalHeight)
                    } else {
                        Logger.warning("高度仍为0，使用默认160", category: .adSlot)
                        self.updateContainerHeight(160)
                    }
                }
            } else {
                Logger.warning("无法获取canvasView", category: .adSlot)
            }
        }
        
        func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
            Logger.error("信息流广告加载失败: \(error?.localizedDescription ?? "未知错误")", category: .adSlot)
        }
        
        // MARK: - BUMNativeAdDelegate
        
        func nativeAdDidBecomeVisible(_ nativeAd: BUNativeAd) {
            Logger.success("信息流广告展示成功", category: .adSlot)
        }
        
        func nativeAdDidClick(_ nativeAd: BUNativeAd, with view: UIView?) {
            Logger.info("信息流广告被点击", category: .adSlot)
        }
        
        func nativeAd(_ nativeAd: BUNativeAd?, dislikeWithReason filterWords: [BUDislikeWords]?) {
            Logger.info("用户负反馈，移除广告", category: .adSlot)
            DispatchQueue.main.async {
                self.containerView?.subviews.forEach { $0.removeFromSuperview() }
                self.updateContainerHeight(0)
            }
        }
        
        // 模板广告渲染成功回调 - 关键方法（修复版）
        func nativeAdExpressViewRenderSuccess(_ nativeAd: BUNativeAd) {
            Logger.success("模板广告渲染成功", category: .adSlot)
            
            
            
            guard let canvasView = nativeAd.mediation?.canvasView else {
                Logger.error("无法获取canvasView", category: .adSlot)
                return
            }
            
            // 延迟获取高度，确保布局完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // 强制完成布局
                canvasView.setNeedsLayout()
                canvasView.layoutIfNeeded()
                
                // 获取多个高度值进行对比
                let boundsHeight = canvasView.bounds.height
                let frameHeight = canvasView.frame.height
                let intrinsicHeight = canvasView.intrinsicContentSize.height
                
                Logger.info("广告视图高度信息:", category: .adSlot)
                Logger.info("  bounds.height: \(boundsHeight)", category: .adSlot)
                Logger.info("  frame.height: \(frameHeight)", category: .adSlot)
                Logger.info("  intrinsicContentSize.height: \(intrinsicHeight)", category: .adSlot)
                
                // 选择最合适的高度值
                let finalHeight = self.selectBestHeight(
                    bounds: boundsHeight,
                    frame: frameHeight,
                    intrinsic: intrinsicHeight
                )
                
                if finalHeight > 0 {
                    Logger.success("使用最终高度: \(finalHeight)", category: .adSlot)
                    self.updateContainerHeight(finalHeight)
                } else {
                    Logger.warning("所有高度值无效，使用默认值", category: .adSlot)
                    self.updateContainerHeight(160)
                }
            }
        }
        
        func nativeAdExpressViewRenderFail(_ nativeAd: BUNativeAd, error: Error?) {
            Logger.error("模板广告渲染失败: \(error?.localizedDescription ?? "未知错误")", category: .adSlot)
        }
        
        // MARK: - Private Methods
        
        private func selectBestHeight(bounds: CGFloat, frame: CGFloat, intrinsic: CGFloat) -> CGFloat {
            // 优先级：bounds > frame > intrinsic
            if bounds > 0 && bounds != CGFloat.greatestFiniteMagnitude {
                return bounds
            }
            
            if frame > 0 && frame != CGFloat.greatestFiniteMagnitude {
                return frame
            }
            
            if intrinsic > 0 && intrinsic != CGFloat.greatestFiniteMagnitude {
                return intrinsic
            }
            
            return 0
        }
        
        private func updateContainerHeight(_ newHeight: CGFloat) {
            guard let containerView = self.containerView else { return }
            
            // 更新容器高度约束
            heightConstraint?.constant = newHeight
            
            // 触发布局更新
            containerView.setNeedsLayout()
            containerView.layoutIfNeeded()
            
            // 通知SwiftUI更新
            parent.updateHeight(newHeight)
            
            Logger.info("容器高度约束已更新为: \(newHeight)", category: .adSlot)
        }
        
        private func handleCustomRenderAd(ad: BUNativeAd) {
            Logger.info("处理自渲染广告，标题: \(ad.data?.adTitle ?? "无标题")", category: .adSlot)
            // 自渲染广告的处理逻辑
            // 这里需要根据具体需求实现自定义渲染
            updateContainerHeight(160) // 自渲染广告使用默认高度
        }
        
        // MARK: - 其他BUMNativeAdDelegate方法
        
        func nativeAdWillPresentFullScreenModal(_ nativeAd: BUNativeAd) {
            Logger.info("信息流广告即将展示详情页", category: .adSlot)
        }
        
        func nativeAdDidDismissFullScreenModal(_ nativeAd: BUNativeAd) {
            Logger.info("信息流广告详情页已关闭", category: .adSlot)
        }
        
        func nativeAdWillLeaveApplication(_ nativeAd: BUNativeAd) {
            Logger.info("信息流广告即将跳转到其他应用", category: .adSlot)
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

