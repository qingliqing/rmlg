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
         refreshInterval: TimeInterval = 30.0,
         containerSize: CGSize = CGSize(width: UIScreen.main.bounds.width, height: 160),
         backgroundColor: UIColor = .systemBackground) {
        
        self._adManager = StateObject(wrappedValue: BannerAdManager(
            slotId: slotId,
            refreshInterval: refreshInterval,
            defaultAdSize: containerSize
        ))
        self.containerSize = containerSize
        self.backgroundColor = backgroundColor
    }
    
    // MARK: - UIViewRepresentable
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = backgroundColor
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // 获取根视图控制器
        guard let viewController = uiView.findViewController() else {
            print("无法找到根视图控制器")
            return
        }
        
        // 清理之前的广告视图
        uiView.subviews.forEach { $0.removeFromSuperview() }
        
        // 加载新广告
        adManager.loadBannerAd(in: viewController, containerSize: containerSize)
        
        // 添加广告视图到容器
        if let bannerView = adManager.getBannerView() {
            uiView.addSubview(bannerView)
            
            // 设置约束使广告居中
            bannerView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                bannerView.centerXAnchor.constraint(equalTo: uiView.centerXAnchor),
                bannerView.centerYAnchor.constraint(equalTo: uiView.centerYAnchor),
                bannerView.leadingAnchor.constraint(greaterThanOrEqualTo: uiView.leadingAnchor, constant: 8),
                bannerView.trailingAnchor.constraint(lessThanOrEqualTo: uiView.trailingAnchor, constant: -8)
            ])
        }
    }
    
    static func dismantleUIView(_ uiView: UIView, coordinator: ()) {
        // 清理资源
        uiView.subviews.forEach { $0.removeFromSuperview() }
    }
}

// MARK: - UIView Extension
extension UIView {
    func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
}

// MARK: - SwiftUI Banner广告组件（带状态显示）
struct AdaptiveBannerAdView: View {
    
    // MARK: - Properties
    @StateObject private var adManager = BannerAdManager()
    
    let slotId: String
    let refreshInterval: TimeInterval
    let maxHeight: CGFloat
    let showLoadingIndicator: Bool
    let showErrorMessage: Bool
    
    // MARK: - Initialization
    init(slotId: String = "103585837",
         refreshInterval: TimeInterval = 30.0,
         maxHeight: CGFloat = 200,
         showLoadingIndicator: Bool = true,
         showErrorMessage: Bool = true) {
        
        self.slotId = slotId
        self.refreshInterval = refreshInterval
        self.maxHeight = maxHeight
        self.showLoadingIndicator = showLoadingIndicator
        self.showErrorMessage = showErrorMessage
    }
    
    // MARK: - Body
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                
                if adManager.isLoading && showLoadingIndicator {
                    // 加载状态
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("广告加载中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if let errorMessage = adManager.errorMessage, showErrorMessage {
                    // 错误状态
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                        
                        Button("重试") {
                            adManager.refreshAd()
                        }
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    }
                    .padding()
                } else if adManager.isLoaded {
                    // 广告内容
                    BannerAdView(
                        slotId: slotId,
                        refreshInterval: refreshInterval,
                        containerSize: geometry.size,
                        backgroundColor: .clear
                    )
                } else {
                    // 默认占位符
                    VStack {
                        Image(systemName: "rectangle.dashed")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("广告位")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxHeight: min(adManager.adSize.height, maxHeight))
        .clipped()
    }
}
