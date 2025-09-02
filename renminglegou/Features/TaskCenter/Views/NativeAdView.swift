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
        
        // 创建广告管理器
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.loadAd(in: containerView, slotId: slotId)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 当SwiftUI需要更新时调用
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // 内部方法：更新高度
    private mutating func updateHeight(_ newHeight: CGFloat) {
        if newHeight != adHeight && newHeight > 0 {
            adHeight = newHeight
            onHeightChanged?(newHeight)
            print("📏 [信息流广告] 高度更新: \(newHeight)")
        }
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, BUMNativeAdsManagerDelegate, BUMNativeAdDelegate, BUCustomEventProtocol {
        var parent: NativeAdView
        private var currentAd: BUNativeAd?
        private var adManager: BUNativeAdsManager?
        private weak var containerView: UIView?
        
        init(_ parent: NativeAdView) {
            self.parent = parent
        }
        
        func loadAd(in containerView: UIView, slotId: String) {
            self.containerView = containerView
            
            print("🚀 [信息流广告] 开始加载广告, SlotID: \(slotId)")
            
            // 销毁上次广告对象
            adManager?.mediation?.destory()
            
            // 创建广告位配置
            let slot = BUAdSlot()
            slot.id = slotId
            slot.adType = BUAdSlotAdType.feed
            slot.position = BUAdSlotPosition.feed
            
            // 设置广告位尺寸
            let screenWidth = DeviceConsts.screenWidth - 40
            slot.adSize = CGSize(width: screenWidth, height: 0)
            slot.mediation.mutedIfCan = false
            
            print("📐 [信息流广告] 设置广告位尺寸: \(screenWidth) x 0 (自适应)")
            
            // 创建广告管理器
            let manager = BUNativeAdsManager(slot: slot)
            if let rootVC = UIUtils.findViewController() {
                manager.mediation?.rootViewController = rootVC
                print("🏠 [信息流广告] 设置根视图控制器成功")
            }
            
            // 设置Manager的代理
            manager.delegate = self
            print("📋 [信息流广告] 设置Manager代理成功")
            
            self.adManager = manager
            manager.loadAdData(withCount: 1)
        }
        
        private func setupAdView(adView: UIView, in containerView: UIView) {
            // 清除之前的广告视图
            containerView.subviews.forEach { $0.removeFromSuperview() }
            
            // 添加新的广告视图
            containerView.addSubview(adView)
            adView.translatesAutoresizingMaskIntoConstraints = false
            
            print("📏 [信息流广告] 广告视图初始frame尺寸: \(adView.frame.size)")
            
            // 设置约束
            let constraints = [
                adView.topAnchor.constraint(equalTo: containerView.topAnchor),
                adView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                adView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            ]
            NSLayoutConstraint.activate(constraints)
            
            print("📐 [信息流广告] 广告视图约束设置完成")
        }
        
        private func customRenderAd(ad: BUNativeAd) {
            print("📝 [信息流广告] 需要自渲染广告，标题: \(ad.data?.adTitle ?? "无标题")")
        }
        
        // MARK: - BUMNativeAdsManagerDelegate
        
        func nativeAdsManagerSuccess(toLoad adsManager: BUNativeAdsManager, nativeAds nativeAdDataArray: [BUNativeAd]?) {
            guard let adList = nativeAdDataArray,
                  let firstAd = adList.first,
                  let containerView = self.containerView else {
                print("❌ [信息流广告] 广告数据为空或容器视图无效")
                return
            }
            
            self.currentAd = firstAd
            print("✅ [信息流广告] 广告加载成功，广告数量: \(adList.count)")
            
            // 按照官方文档设置
            if let rootVC = UIUtils.findViewController(){
                firstAd.rootViewController = rootVC
                print("🏠 [信息流广告] 设置广告rootViewController成功")
            }
            firstAd.delegate = self
            
            // 添加canvasView到容器
            if let canvasView = firstAd.mediation?.canvasView {
                DispatchQueue.main.async {
                    print("📱 [信息流广告] 准备添加canvasView到容器")
                    self.setupAdView(adView: canvasView, in: containerView)
                }
            } else {
                print("⚠️ [信息流广告] 无法获取canvasView")
            }
            
            // 处理模板广告
            if let isExpressAd = firstAd.mediation?.isExpressAd, isExpressAd {
                print("🎨 [信息流广告] 检测到模板广告，开始渲染")
                firstAd.mediation?.render()
            } else {
                print("🔧 [信息流广告] 检测到自渲染广告")
                customRenderAd(ad: firstAd)
            }
        }
        
        func nativeAdsManager(_ adsManager: BUNativeAdsManager, didFailWithError error: Error?) {
            print("❌ [信息流广告] 加载失败: \(error?.localizedDescription ?? "未知错误")")
        }
        
        // MARK: - BUMNativeAdDelegate (继承自BUNativeAdDelegate)
        
        // 基础展示回调
        func nativeAdDidBecomeVisible(_ nativeAd: BUNativeAd) {
            print("👀 [信息流广告] 展示成功")
        }
        
        func nativeAdDidClick(_ nativeAd: BUNativeAd, with view: UIView?) {
            print("👆 [信息流广告] 被点击")
        }
        
        func nativeAd(_ nativeAd: BUNativeAd?, dislikeWithReason filterWords: [BUDislikeWords]?) {
            print("👎 [信息流广告] 用户负反馈，移除广告")
            DispatchQueue.main.async {
                self.containerView?.subviews.forEach { $0.removeFromSuperview() }
                self.parent.updateHeight(0)
            }
        }
        
        // BUMNativeAdDelegate特有方法
        func nativeAdWillPresentFullScreenModal(_ nativeAd: BUNativeAd) {
            print("📱 [信息流广告] 即将展示详情页")
        }
        
        // 模板广告渲染成功回调 - 关键方法
        func nativeAdExpressViewRenderSuccess(_ nativeAd: BUNativeAd) {
            print("🎨 [信息流广告] 模板广告渲染成功")
            
            if let canvasView = nativeAd.mediation?.canvasView {
                DispatchQueue.main.async {
                    canvasView.layoutIfNeeded()
                    let realHeight = canvasView.bounds.height
                    
                    print("📏 [信息流广告] 渲染成功，获取高度:")
                    print("   canvasView.bounds.size: \(canvasView.bounds.size)")
                    print("   canvasView.frame.size: \(canvasView.frame.size)")
                    print("   使用高度: \(realHeight)")
                    
                    if realHeight > 0 {
                        self.parent.updateHeight(realHeight)
                        print("🔄 [信息流广告] 高度已更新为: \(realHeight)")
                    } else {
                        print("⚠️ [信息流广告] 获取到的高度无效，使用默认值")
                        self.parent.updateHeight(160)
                    }
                }
            } else {
                print("❌ [信息流广告] 无法获取canvasView")
            }
        }
        
        // 模板广告渲染失败回调
        func nativeAdExpressViewRenderFail(_ nativeAd: BUNativeAd, error: Error?) {
            print("❌ [信息流广告] 模板广告渲染失败: \(error?.localizedDescription ?? "未知错误")")
        }
        
        // 视频相关回调
        func nativeAdVideo(_ nativeAd: BUNativeAd?, stateDidChanged playerState: BUPlayerPlayState) {
            print("📹 [信息流广告] 视频播放状态变更: \(playerState.rawValue)")
        }
        
        func nativeAdVideoDidClick(_ nativeAd: BUNativeAd?) {
            print("📹 [信息流广告] 视频被点击")
        }
        
        func nativeAdVideoDidPlayFinish(_ nativeAd: BUNativeAd?) {
            print("📹 [信息流广告] 视频播放完成")
        }
        
        func nativeAdShakeViewDidDismiss(_ nativeAd: BUNativeAd?) {
            print("📱 [信息流广告] 摇一摇提示view消除")
        }
        
        func nativeAdVideo(_ nativeAdView: BUNativeAd?, rewardDidCountDown countDown: Int) {
            print("⏰ [信息流广告] 激励视频倒计时: \(countDown)")
        }
    }
}

