//
//  NetworkManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 网络请求管理器
class NetworkManager {
    static let shared = NetworkManager()
    
    private let session: Session
    
    private init() {
        // 配置 Session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = NetworkAPI.timeout
        configuration.timeoutIntervalForResource = NetworkAPI.timeout
        
        // 创建拦截器处理认证
        let interceptor = AuthenticationInterceptor()
        
        self.session = Session(
            configuration: configuration,
            interceptor: interceptor
        )
    }
    
    // MARK: - 通用请求方法
    func request<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type,
        completion: @escaping (Result<T, NetworkError>) -> Void
    ) {
        guard let url = endpoint.url else {
            completion(.failure(.invalidURL))
            return
        }
        
        session.request(
            url,
            method: endpoint.method,
            parameters: endpoint.parameters,
            encoding: endpoint.encoding,
            headers: endpoint.headers
        )
        .validate()
        .responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    // 如果响应类型是 Empty，直接返回成功
                    if T.self == Empty.self {
                        completion(.success(Empty() as! T))
                        return
                    }
                    
                    // 尝试解析为 APIResponse<T>
                    let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
                    if let responseData = apiResponse.data {
                        completion(.success(responseData))
                    } else if apiResponse.success {
                        // 如果成功但没有数据，返回空对象
                        completion(.success(Empty() as! T))
                    } else {
                        completion(.failure(.serverError(apiResponse.message ?? "未知错误")))
                    }
                } catch {
                    // 如果无法解析为 APIResponse，尝试直接解析为 T
                    do {
                        let directResponse = try JSONDecoder().decode(T.self, from: data)
                        completion(.success(directResponse))
                    } catch {
                        print("解码错误: \(error)")
                        completion(.failure(.decodingError))
                    }
                }
            case .failure(let error):
                completion(.failure(.networkError(error)))
            }
        }
    }
    
    // MARK: - Async/Await 版本
    @available(iOS 13.0, *)
    func request<T: Codable>(
        endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            request(endpoint: endpoint, responseType: responseType) { result in
                continuation.resume(with: result)
            }
        }
    }
}

// MARK: - 认证拦截器
final class AuthenticationInterceptor: RequestInterceptor, @unchecked Sendable {
    func adapt(_ urlRequest: URLRequest, for session: Session, completion: @escaping (Result<URLRequest, Error>) -> Void) {
        var urlRequest = urlRequest
        
        // 添加用户令牌（如果存在）
        if let token = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.userToken) {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        completion(.success(urlRequest))
    }
}

// MARK: - API 端点协议
protocol APIEndpoint {
    var path: String { get }
    var method: HTTPMethod { get }
    var parameters: Parameters? { get }
    var encoding: ParameterEncoding { get }
    var headers: HTTPHeaders? { get }
    var url: URL? { get }
}

extension APIEndpoint {
    var url: URL? {
        return URL(string: NetworkAPI.baseURL + path)
    }
    
    var encoding: ParameterEncoding {
        switch method {
        case .get:
            return URLEncoding.default
        default:
            return URLEncoding.httpBody
        }
    }
    
    var headers: HTTPHeaders? {
        return ["Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"]
    }
}
