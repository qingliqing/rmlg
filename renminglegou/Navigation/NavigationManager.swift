//
//  NavigationManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/14.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case taskCenter(params: [String: AnyHashable]? = nil)
    case webView(url: URL, title: String = "", showBackButton: Bool = true)
}

@available(iOS 16.0, *)
class NavigationManager: ObservableObject {
    @Published var path = NavigationPath()
    
    func navigateTo(_ destination: NavigationDestination) {
        path.append(destination)
    }
    
    func goBack() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path = NavigationPath()
    }
}
