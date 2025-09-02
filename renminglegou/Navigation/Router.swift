//
//  Router.swift
//  renminglegou
//

// Router.swift
import SwiftUI

@available(iOS 16.0, *)
class Router: ObservableObject {
    static let shared = Router()
    
    @Published var path = NavigationPath()
    @Published private(set) var routes: [AppRoute] = []  // ✅ 显式存放路由栈
    
    private init() {}
    
    // MARK: - 基础跳转
    
    func push(_ route: AppRoute) {
        routes.append(route)
        path.append(route)
    }
    
    func pushReplace(_ route: AppRoute) {
        if !routes.isEmpty {
            routes.removeLast()
            path.removeLast()
        }
        push(route)
    }
    
    func pop() {
        if !routes.isEmpty {
            routes.removeLast()
            path.removeLast()
        }
    }
    
    func popTo(_ route: AppRoute) {
        guard let index = routes.firstIndex(of: route) else { return }
        let removeCount = routes.count - index - 1
        if removeCount > 0 {
            routes.removeLast(removeCount)
            for _ in 0..<removeCount {
                path.removeLast()
            }
        }
    }
    
    func popToRoot() {
        routes.removeAll()
        path = NavigationPath()
    }
    
    func resetTo(_ route: AppRoute) {
        routes = [route]
        path = NavigationPath()
        path.append(route)
    }
    
    // MARK: - Present / Dismiss (UIKit)
    func present<Content: View>(_ view: Content, animated: Bool = true) {
        guard let rootVC = getRootViewController() else { return }
        let hosting = UIHostingController(rootView: view)
        hosting.modalPresentationStyle = .fullScreen
        rootVC.present(hosting, animated: animated)
    }
    
    func dismiss(animated: Bool = true) {
        guard let rootVC = getRootViewController() else { return }
        rootVC.dismiss(animated: animated)
    }
}

// MARK: - 静态方法代理
@available(iOS 16.0, *)
extension Router {
    static func push(_ route: AppRoute) { shared.push(route) }
    static func pushReplace(_ route: AppRoute) { shared.pushReplace(route) }
    static func pop() { shared.pop() }
    static func popTo(_ route: AppRoute) { shared.popTo(route) }
    static func popToRoot() { shared.popToRoot() }
    static func resetTo(_ route: AppRoute) { shared.resetTo(route) }
    static func present<Content: View>(_ view: Content, animated: Bool = true) { shared.present(view, animated: animated) }
    static func dismiss(animated: Bool = true) { shared.dismiss(animated: animated) }
}
