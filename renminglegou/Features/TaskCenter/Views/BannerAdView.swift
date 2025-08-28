//
//  BannerAdView.swift
//  renminglegou
//
//  Created by Developer on 2025/8/27.
//

import UIKit
import SwiftUI

// MARK: - SwiftUI Banner广告视图
struct BannerAdView: UIViewRepresentable {
    
    // MARK: - Properties
    @StateObject private var adManager: BannerAdManager
    let containerSize: CGSize
    let backgroundColor: UIColor
    
    // MARK: - Initialization
    init(slotId: String = "103585837",
         containerSize: CGSize = CGSize(width: UIScreen.main.bounds.width - 40, height: 160),
         backgroundColor: UIColor = .systemBackground) {
        
        self._adManager = StateObject(wrappedValue: BannerAdManager(
            slotId: slotId,
            defaultAdSize: containerSize
        ))
        self.containerSize = containerSize
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> BannerContainerView {
        let containerView = BannerContainerView()
        containerView.backgroundColor = backgroundColor
        containerView.adManager = adManager
        containerView.containerSize = containerSize
        containerView.layer.cornerRadius = 16
        containerView.layer.masksToBounds = true
        return containerView
    }
    
    func updateUIView(_ uiView: BannerContainerView, context: Context) {
        // 只在容器视图中更新尺寸
        uiView.containerSize = containerSize
    }
    
    static func dismantleUIView(_ uiView: BannerContainerView, coordinator: ()) {
        uiView.cleanup()
    }
}

// MARK: - 专用容器视图
class BannerContainerView: UIView {
    
    var adManager: BannerAdManager?
    var containerSize: CGSize = .zero {
        didSet {
            if containerSize != oldValue {
                setupAdIfNeeded()
            }
        }
    }
    
    private var hasSetupAd = false
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        // 当视图添加到窗口时，尝试设置广告
        if window != nil {
            setupAdIfNeeded()
        }
    }
    
    private func setupAdIfNeeded() {
        guard !hasSetupAd,
              let adManager = adManager,
              let viewController = findViewController(),
              containerSize != .zero else {
            return
        }
        
        hasSetupAd = true
        
        Task { @MainActor in
            print("容器视图开始初始化广告")
            adManager.initializeAd(in: viewController, containerSize: containerSize)
            
            // 监听广告加载完成
            setupAdLoadedObserver()
        }
    }
    
    private func setupAdLoadedObserver() {
        guard let adManager = adManager else { return }
        
        // 创建一个定时器来检查广告是否加载完成
        let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self, weak adManager] timer in
            guard let self = self,
                  let adManager = adManager,
                  let bannerView = adManager.getBannerView() else {
                return
            }
            
            // 停止定时器
            timer.invalidate()
            
            // 在主线程中添加广告视图
            DispatchQueue.main.async {
                self.addBannerView(bannerView)
            }
        }
        
        // 10秒后自动停止定时器（防止内存泄漏）
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            timer.invalidate()
        }
    }
    
    private func addBannerView(_ bannerView: UIView) {
        // 移除旧的广告视图
        subviews.forEach { $0.removeFromSuperview() }
        
        // 添加新的广告视图
        addSubview(bannerView)
        
        // 设置约束 - 防止超出边界
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.topAnchor.constraint(equalTo: topAnchor),
            bannerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            bannerView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        print("Banner广告视图已添加到容器")
        print("容器尺寸: \(bounds.size)")
        print("广告尺寸: \(bannerView.frame.size)")
    }
    
    func cleanup() {
        hasSetupAd = false
        subviews.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - 改进的 UIView Extension
extension UIView {
    func findViewController() -> UIViewController? {
        // 方法1: 通过响应链查找
        var nextResponder = self.next
        while nextResponder != nil {
            if let viewController = nextResponder as? UIViewController {
                return viewController
            }
            nextResponder = nextResponder?.next
        }
        
        // 方法2: 通过场景查找
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: \.isKeyWindow),
           let rootViewController = window.rootViewController {
            return findTopViewController(from: rootViewController)
        }
        
        return nil
    }
    
    private func findTopViewController(from root: UIViewController) -> UIViewController {
        if let presented = root.presentedViewController {
            return findTopViewController(from: presented)
        }
        
        if let navigationController = root as? UINavigationController,
           let topController = navigationController.topViewController {
            return findTopViewController(from: topController)
        }
        
        if let tabBarController = root as? UITabBarController,
           let selectedController = tabBarController.selectedViewController {
            return findTopViewController(from: selectedController)
        }
        
        return root
    }
}
