//
//  NetworkLogger.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 网络日志配置
struct NetworkLoggerConfig {
    /// 是否启用日志
    static var isEnabled: Bool = true
    
    /// 是否启用详细模式（包含请求体和响应体）
    static var isVerboseMode: Bool = true
    
    /// 响应体最大显示长度
    static var maxResponseBodyLength: Int = 2000
    
    /// 是否在Release模式下启用
    static var enableInRelease: Bool = false
}

// MARK: - 网络日志工具
class NetworkLogger {
    
    // MARK: - 单例
    static let shared = NetworkLogger()
    private init() {}
    
    // MARK: - 日志开关检查
    private var shouldLog: Bool {
        #if DEBUG
        return NetworkLoggerConfig.isEnabled
        #else
        return NetworkLoggerConfig.isEnabled && NetworkLoggerConfig.enableInRelease
        #endif
    }
    
    // MARK: - 公共日志方法
    
    /// 记录请求开始
    func logRequest(
        url: URL,
        method: HTTPMethod,
        parameters: Parameters?,
        headers: HTTPHeaders,
        responseType: Any.Type
    ) {
        guard shouldLog else { return }
        
        print("\n" + "="*80)
        print("📤 网络请求开始")
        print("="*80)
        print("🔗 URL: \(url.absoluteString)")
        print("🎯 Method: \(method.rawValue)")
        print("📝 Response Type: \(responseType)")
        print("⏰ Time: \(currentTimeString)")
        
        if NetworkLoggerConfig.isVerboseMode {
            logParameters(parameters)
            logHeaders(headers)
        }
        
        print("="*80)
    }
    
    /// 记录响应
    func logResponse<T>(
        response: AFDataResponse<T>,
        url: URL,
        method: HTTPMethod
    ) {
        guard shouldLog else { return }
        
        print("\n" + "="*80)
        print("📥 网络响应")
        print("="*80)
        print("🔗 URL: \(url.absoluteString)")
        print("🎯 Method: \(method.rawValue)")
        print("⏰ Time: \(currentTimeString)")
        
        logStatusCode(response.response)
        
        if NetworkLoggerConfig.isVerboseMode {
            logResponseBody(response.data)
        }
        
        if let error = response.error {
            logNetworkError(error)
        }
        
        print("="*80)
    }
    
    /// 记录成功解析
    func logSuccess(message: String, responseType: Any.Type) {
        guard shouldLog else { return }
        print("✅ \(message) - 类型: \(responseType)")
    }
    
    /// 记录警告
    func logWarning(message: String, error: Error? = nil) {
        guard shouldLog else { return }
        print("⚠️  \(message)")
        if let error = error {
            print("   详情: \(error.localizedDescription)")
        }
    }
    
    /// 记录错误
    func logError(message: String, error: Error) {
        guard shouldLog else { return }
        print("❌ \(message)")
        print("   错误详情: \(error.localizedDescription)")
        print("   错误类型: \(type(of: error))")
    }
    
    /// 记录自定义消息
    func log(_ message: String, level: LogLevel = .info) {
        guard shouldLog else { return }
        print("\(level.emoji) \(message)")
    }
}

// MARK: - 私有辅助方法
private extension NetworkLogger {
    
    /// 当前时间字符串
    var currentTimeString: String {
        DateFormatter.logFormatter.string(from: Date())
    }
    
    /// 记录请求参数
    func logParameters(_ parameters: Parameters?) {
        if let parameters = parameters, !parameters.isEmpty {
            print("📋 Parameters:")
            for (key, value) in parameters {
                print("   \(key): \(value)")
            }
        } else {
            print("📋 Parameters: 无")
        }
    }
    
    /// 记录请求头
    func logHeaders(_ headers: HTTPHeaders) {
        print("📨 Headers:")
        for header in headers {
            if header.name.lowercased().contains("authorization") {
                // 隐藏敏感信息
                print("   \(header.name): Bearer ***")
            } else {
                print("   \(header.name): \(header.value)")
            }
        }
    }
    
    /// 记录状态码
    func logStatusCode(_ response: HTTPURLResponse?) {
        if let httpResponse = response {
            let statusCode = httpResponse.statusCode
            let statusEmoji = statusCode >= 200 && statusCode < 300 ? "✅" : "❌"
            print("\(statusEmoji) Status Code: \(statusCode)")
        }
    }
    
    /// 记录响应体
    func logResponseBody(_ data: Data?) {
        if let data = data {
            print("📊 Response Size: \(data.count) bytes")
            
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📄 Response Body:")
                
                // 格式化JSON输出
                let formattedJson = formatJsonString(jsonString)
                let truncatedString = formattedJson.count > NetworkLoggerConfig.maxResponseBodyLength
                    ? String(formattedJson.prefix(NetworkLoggerConfig.maxResponseBodyLength)) + "\n... (内容被截断)"
                    : formattedJson
                
                print(truncatedString)
            } else {
                print("📄 Response Body: [二进制数据，无法显示]")
            }
        } else {
            print("📄 Response Body: 无数据")
        }
    }
    
    /// 记录网络错误
    func logNetworkError(_ error: AFError) {
        print("❌ Network Error: \(error.localizedDescription)")
        
        // 详细错误信息
        switch error {
        case .responseValidationFailed(let reason):
            print("   验证失败: \(reason)")
        case .responseSerializationFailed(let reason):
            print("   序列化失败: \(reason)")
        default:
            break
        }
    }
    
    /// 格式化JSON字符串
    func formatJsonString(_ jsonString: String) -> String {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
              let prettyJsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
              let prettyJsonString = String(data: prettyJsonData, encoding: .utf8) else {
            return jsonString
        }
        return prettyJsonString
    }
}

// MARK: - 日志级别
enum LogLevel {
    case info
    case warning
    case error
    case success
    
    var emoji: String {
        switch self {
        case .info:
            return "ℹ️"
        case .warning:
            return "⚠️"
        case .error:
            return "❌"
        case .success:
            return "✅"
        }
    }
}

// MARK: - 扩展支持
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}

extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}
