import Alamofire
import SwiftUI
import Combine

// MARK: - 认证状态管理器
final class AuthenticationState: ObservableObject {
    static let shared = AuthenticationState()
    
    @Published var isAuthenticated: Bool = true
    
    func checkAuthenticationStatus() {
        if let token = UserDefaults.standard.string(forKey: UserDefaultsKeys.userToken),
           !token.isEmpty {
            isAuthenticated = true
        } else {
            isAuthenticated = false
        }
    }
    
    // 登录成功
    func loginSuccess() {
        isAuthenticated = true
    }
    
    // 登录失效
    @MainActor
    func logout() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.userToken)
        UserDefaults.standard.synchronize()
        
        isAuthenticated = false
    }
}


// MARK: - 认证拦截器
final class AuthenticationInterceptor: RequestInterceptor, @unchecked Sendable {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        
        // 添加用户令牌（如果存在）
        if let token = UserDefaults.standard.string(forKey: UserDefaultsKeys.userToken) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        completion(.success(urlRequest))
    }
    
    func retry(_ request: Request, for session: Session, dueTo error: Error, completion: @escaping (RetryResult) -> Void) {
        // 这里只处理网络错误重试，不处理认证失效
        completion(.doNotRetry)
    }
}

// 响应监控器：负责检查401状态码
final class AuthenticationMonitor: EventMonitor {
    let queue = DispatchQueue(label: "AuthenticationMonitor")
    
    // 🔥 这个方法会在每个响应被解析后调用，无论成功还是失败
    func request<Value>(_ request: DataRequest, didParseResponse response: DataResponse<Value, AFError>) {
        if let httpResponse = response.response, httpResponse.statusCode == 401 {
            print("🚨 检测到401状态码，执行登录失效逻辑")
            handleAuthenticationFailure()
        }
    }
    
    private func handleAuthenticationFailure() {
        Task {
            await MainActor.run {
                AuthenticationState.shared.logout()
            }
        }
    }
}
