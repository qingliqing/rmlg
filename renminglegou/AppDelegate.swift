//
//  AppDelegate.swift
//  renminglegou
//
//  Created by Developer on 9/7/25.
//

import UIKit
import Foundation

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        
        print("收到 URL 回调: \(url)")
        
        // 处理银联支付回调
        UPPaymentControl.default().handlePaymentResult(url) { code, data in
            DispatchQueue.main.async {
                print("支付结果: \(code)")
                
                // 发送通知给 SwiftUI
                NotificationCenter.default.post(
                    name: .unionPayResult,
                    object: ["code": code, "data": data ?? [:]]
                )
            }
        }
        
        return true
    }
}

// 扩展通知名称
extension Notification.Name {
    static let unionPayResult = Notification.Name("unionPayResult")
}
