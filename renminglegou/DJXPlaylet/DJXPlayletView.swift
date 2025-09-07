//
//  DJXPlayletView.swift
//  renminglegou
//
//  Created by Developer on 9/7/25.
//

import SwiftUI
import PangrowthDJX

// MARK: - 短剧页面配置
struct DJXPlayletPageConfig: Equatable, Hashable {
    var freeEpisodesCount: Int = 10
    var unlockEpisodesCountUsingAD: Int = 5
    var playletUnlockADMode: DJXPlayletUnlockADModeOptions = .common
    var isShowNavigationItemTitle: Bool = true
    var isShowNavigationItemBackButton: Bool = true
    
    // MARK: - Equatable
    static func == (lhs: DJXPlayletPageConfig, rhs: DJXPlayletPageConfig) -> Bool {
        return lhs.freeEpisodesCount == rhs.freeEpisodesCount &&
               lhs.unlockEpisodesCountUsingAD == rhs.unlockEpisodesCountUsingAD &&
               lhs.playletUnlockADMode == rhs.playletUnlockADMode &&
               lhs.isShowNavigationItemTitle == rhs.isShowNavigationItemTitle &&
               lhs.isShowNavigationItemBackButton == rhs.isShowNavigationItemBackButton
    }
    
    // MARK: - Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(freeEpisodesCount)
        hasher.combine(unlockEpisodesCountUsingAD)
        hasher.combine(playletUnlockADMode.rawValue) // 使用 rawValue
        hasher.combine(isShowNavigationItemTitle)
        hasher.combine(isShowNavigationItemBackButton)
    }
}


// MARK: - SwiftUI 包装的短剧页面
struct DJXPlayletView: UIViewControllerRepresentable {
    let config: DJXPlayletPageConfig
    let onDismiss: (() -> Void)?
    
    init(config: DJXPlayletPageConfig = DJXPlayletPageConfig(),
         onDismiss: (() -> Void)? = nil) {
        self.config = config
        self.onDismiss = onDismiss
    }
    
    func makeUIViewController(context: Context) -> DJXNavigationController {
        let vc = DJXPlayletAggregatePageViewController { config in
            let playletConfig = DJXPlayletConfig()
            playletConfig.freeEpisodesCount = self.config.freeEpisodesCount
            playletConfig.unlockEpisodesCountUsingAD = self.config.unlockEpisodesCountUsingAD
            playletConfig.playletUnlockADMode = self.config.playletUnlockADMode
            
            config.playletConfig = playletConfig
            config.isShowNavigationItemTitle = self.config.isShowNavigationItemTitle
            config.isShowNavigationItemBackButton = self.config.isShowNavigationItemBackButton
            
        }
        let navVC = DJXNavigationController(rootViewController: vc)
        navVC.onPopCallback = {
            DispatchQueue.main.async {
                Router.shared.pop()
                self.onDismiss?()
            }
        }
        
        return navVC
    }
    
    func updateUIViewController(_ uiViewController: DJXNavigationController, context: Context) {
        // 如果需要动态更新配置，在这里实现
    }
}

class DJXNavigationController: UINavigationController {
    var onPopCallback: (() -> Void)?
    
    override func popViewController(animated: Bool) -> UIViewController? {
        print("🔥 拦截到 popViewController")
        onPopCallback?()
        return super.popViewController(animated: animated)
    }
    
    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        print("🔥 拦截到 popToViewController")
        onPopCallback?()
        return super.popToViewController(viewController, animated: animated)
    }
    
    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        print("🔥 拦截到 popToRootViewController")
        onPopCallback?()
        return super.popToRootViewController(animated: animated)
    }
}
