//
//  NetworkManager.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 网络请求管理器
final class NetworkManager: @unchecked Sendable {
    static let shared = NetworkManager()
    
    private let baseURL = NetworkAPI.baseURL // 你的基础URL
    private let session: Session
    private let logger = NetworkLogger.shared
    
    private init() {
        // 配置 Session
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = NetworkAPI.timeout
        configuration.timeoutIntervalForResource = NetworkAPI.timeout
        
        // 拦截器
        let authInterceptor = AuthenticationInterceptor()
        let authMonitor = AuthenticationMonitor()
        
        self.session = Session(
            configuration: configuration,
            interceptor: authInterceptor,
            eventMonitors: [authMonitor]
        )
    }
    
    // MARK: - 私有通用请求方法
    private func performRequest<T: Codable>(
        path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding? = nil,
        responseType: T.Type
    ) async throws -> T {
        
        guard let url = URL(string: baseURL + path) else {
            throw NetworkError.invalidURL
        }
        
        let parameterEncoding: ParameterEncoding = encoding ?? {
            switch method {
            case .get:
                return URLEncoding.default
            default:
                return URLEncoding.httpBody
            }
        }()
        
        let headers: HTTPHeaders = ["Content-Type": "application/x-www-form-urlencoded;charset=UTF-8"]
        
        // 记录请求日志
        logger.logRequest(
            url: url,
            method: method,
            parameters: parameters,
            headers: headers,
            responseType: T.self
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: method,
                parameters: parameters,
                encoding: parameterEncoding,
                headers: headers
            )
            .validate()
            .responseData { response in
                // 记录响应日志
                self.logger.logResponse(response: response, url: url, method: method)
                
                switch response.result {
                case .success(let data):
                    // 添加调试日志
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("🔍 API原始返回：\(jsonString)")
                    }
                    
                    do {
                        // 如果响应类型是 Empty，直接返回成功
                        if T.self == Empty.self {
                            continuation.resume(returning: Empty() as! T)
                            return
                        }
                        
                        // 解析为 APIResponse<T>
                        let apiResponse = try JSONDecoder().decode(APIResponse<T>.self, from: data)
                        if let responseData = apiResponse.data {
                            continuation.resume(returning: responseData)
                        } else {
                            continuation.resume(throwing: NetworkError.serverError(apiResponse.msg ?? "未知错误"))
                        }
                    } catch {
                        print("所有解码尝试都失败: \(error)")
                        continuation.resume(throwing: NetworkError.decodingError)
                    }
                case .failure(let error):
                    continuation.resume(throwing: NetworkError.networkError(error))
                }
            }
        }
    }
    
    
    // MARK: - 公开的通用请求方法（用于API枚举）
    func request<T: Codable>(
        path: String,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding? = nil,
        responseType: T.Type
    ) async throws -> T {
        return try await performRequest(
            path: path,
            method: method,
            parameters: parameters,
            encoding: encoding,
            responseType: responseType
        )
    }
    
    // MARK: - 公开的便捷方法
    
    /// GET 请求
    func get<T: Codable>(
        _ path: String,
        parameters: Parameters? = nil,
        type: T.Type
    ) async throws -> T {
        return try await performRequest(
            path: path,
            method: .get,
            parameters: parameters,
            responseType: type
        )
    }
    
    /// POST 请求
    func post<T: Codable>(
        _ path: String,
        parameters: Parameters? = nil,
        type: T.Type
    ) async throws -> T {
        return try await performRequest(
            path: path,
            method: .post,
            parameters: parameters,
            responseType: type
        )
    }
    
    /// PUT 请求
    func put<T: Codable>(
        _ path: String,
        parameters: Parameters? = nil,
        type: T.Type
    ) async throws -> T {
        return try await performRequest(
            path: path,
            method: .put,
            parameters: parameters,
            responseType: type
        )
    }
    
    /// DELETE 请求
    func delete<T: Codable>(
        _ path: String,
        parameters: Parameters? = nil,
        type: T.Type
    ) async throws -> T {
        return try await performRequest(
            path: path,
            method: .delete,
            parameters: parameters,
            responseType: type
        )
    }
}
