//
//  BUAdTestHelper.swift
//  renminglegou
//
//  Created by abc on 2025/8/21.
//

import SwiftUI
import UIKit
import AdSupport

#if DEBUG
import BUAdTestMeasurement
#endif

class BUAdTestHelper {
    
    /// 显示广告测试工具
    static func showTestMeasurement() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTManager.shared.requestTrackingAuthorization()
        }
        
        #if DEBUG
        guard let rootViewController = getRootViewController() else {
            print("无法获取根视图控制器")
            return
        }
        
        // 显示测试界面
        BUAdTestMeasurementManager.showTestMeasurement(with: rootViewController)
        #else
        print("测试工具仅在 Debug 模式下可用")
        #endif
    }
    
    /// 获取根视图控制器
    private static func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        var topViewController = window.rootViewController
        
        // 获取最顶层的视图控制器
        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }
        
        return topViewController
    }
    
    /// 检查测试工具是否可用
    static var isTestMeasurementAvailable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}
