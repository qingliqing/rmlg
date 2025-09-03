//
//  Router.swift
//  renminglegou
//

import SwiftUI

@available(iOS 16.0, *)
class Router: ObservableObject {
    static let shared = Router()
    
    @Published var path = NavigationPath()
    @Published private(set) var routes: [AppRoute] = []
    
    // 添加一个更新触发器
    @Published private var updateId = UUID()
    
    private init() {}
    
    // MARK: - 基础跳转
    
    func push(_ route: AppRoute) {
        path.append(route)
        routes.append(route)
    }
    
    func pushReplace(_ route: AppRoute) {
        var newPath = routes
        if !newPath.isEmpty {
            newPath.removeLast()
        }
        newPath.append(route)
        
        // 强制刷新 NavigationStack
        DispatchQueue.main.async {
            self.routes = newPath
            self.path = NavigationPath(newPath)
        }
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
            routes.removeLast()
        }
    }
    
    func popTo(_ route: AppRoute) {
        guard let index = routes.firstIndex(of: route) else { return }
        let removeCount = routes.count - index - 1
        if removeCount > 0 {
            routes.removeLast(removeCount)
            rebuildPath()
        }
    }
    
    func popToRoot() {
        routes.removeAll()
        rebuildPath()
    }
    
    func resetTo(_ route: AppRoute) {
        routes = [route]
        rebuildPath()
    }
    
    // MARK: - 核心修复：重建路径方法
    private func rebuildPath() {
        // 使用异步确保状态更新的原子性
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 完全重建 NavigationPath
            var newPath = NavigationPath()
            for route in self.routes {
                newPath.append(route)
            }
            
            self.path = newPath
            self.updateId = UUID() // 强制触发 UI 更新
            
            print("🔄 路由重建: \(self.routes.map { String(describing: $0) }.joined(separator: " → "))")
        }
    }
    
    // MARK: - Present / Dismiss (UIKit)
    func present<Content: View>(_ view: Content, animated: Bool = true) {
        guard let rootVC = UIUtils.findViewController() else { return }
        let hosting = UIHostingController(rootView: view)
        hosting.modalPresentationStyle = .fullScreen
        rootVC.present(hosting, animated: animated)
    }
    
    func dismiss(animated: Bool = true) {
        guard let rootVC = UIUtils.findViewController() else { return }
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
