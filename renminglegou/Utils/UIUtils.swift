//
//  UIUtils.swift
//  renminglegou
//
//  Created by Developer on 8/31/25.
//

import UIKit


struct UIUtils {
    
   static  func findViewController() -> UIViewController? {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
           let window = windowScene.windows.first(where: \.isKeyWindow),
           let rootViewController = window.rootViewController {
            return findTopViewController(from: rootViewController)
        }
        
        return nil
    }

    private static func findTopViewController(from root: UIViewController) -> UIViewController {
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
