//
//  NavigationManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/14.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case taskCenter(params: [String: Any]?)
    
    // 实现 Hashable
    func hash(into hasher: inout Hasher) {
        switch self {
        case .taskCenter:
            hasher.combine("taskCenter")
        }
    }
    
    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.taskCenter, .taskCenter):
            return true
        }
    }
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
