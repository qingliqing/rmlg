//
//  renminglegouApp.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import SwiftUI
import BUAdSDK

@main
struct renminglegouApp: App {
    
    init() {
        setupBUAdSDK()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    private func setupBUAdSDK() {
        /******************** 初始化 ********************/
        let configuration = BUAdSDKConfiguration()
        // 使用聚合
        configuration.useMediation = true
        configuration.appID = "5706508"
        // 隐私合规配置
        // 是否限制个性化广告
        configuration.mediation.limitPersonalAds = NSNumber(integerLiteral: 0)
        // 是否限制程序化广告
        configuration.mediation.limitProgrammaticAds = NSNumber(integerLiteral: 0)
        // 是否禁止CAID
//        configuration.mediation.forbiddenCAID = NSNumber(integerLiteral: 0)
        // 主题模式
        configuration.themeStatus = NSNumber(integerLiteral: 0)
        
        // 初始化
        BUAdSDKManager.start(asyncCompletionHandler:{ success, error in
            if success {
                // 处理成功之后的逻辑
            }
        })

    }
}
