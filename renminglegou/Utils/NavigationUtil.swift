//
//  NavigationUtil.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import SwiftUI
import UIKit

class NavigationUtil {
    static func pushView<Content: View>(_ view: Content, from viewController: UIViewController?) {
        let hostingController = UIHostingController(rootView: view)
        viewController?.navigationController?.pushViewController(hostingController, animated: true)
    }
    
    static func presentView<Content: View>(_ view: Content, from viewController: UIViewController?) {
        let hostingController = UIHostingController(rootView: view)
        viewController?.present(hostingController, animated: true)
    }
    
    static func popViewController(from viewController: UIViewController?) {
        viewController?.navigationController?.popViewController(animated: true)
    }
    
    static func dismissViewController(_ viewController: UIViewController?) {
        viewController?.dismiss(animated: true)
    }
}
