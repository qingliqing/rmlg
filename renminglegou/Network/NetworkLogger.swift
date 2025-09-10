//
//  NetworkLogger.swift (Fixed Thread Safety Issues)
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation
import Alamofire

// MARK: - 网络日志配置
struct NetworkLoggerConfig {
    /// 是否启用网络日志
    static var isEnabled: Bool = true
    
    /// 是否启用详细模式（包含请求体和响应体）
    static var isVerboseMode: Bool = true
    
    /// 响应体最大显示长度（0表示不限制）
    static var maxResponseBodyLength: Int = 0
    
    /// 是否在Release模式下启用
    static var enableInRelease: Bool = false
    
    /// 敏感字段关键字（用于隐藏敏感信息）
    static var sensitiveFields: Set<String> = [
        "authorization", "token", "password", "secret",
        "key", "auth", "bearer", "credential"
    ]
    
    /// 请求超时阈值（秒），超过此时间会标记为慢请求
    static var slowRequestThreshold: TimeInterval = 3.0
}

// MARK: - 网络日志工具
class NetworkLogger {
    
    // MARK: - 单例
    static let shared = NetworkLogger()
    private init() {}
    
    // MARK: - 私有属性
    private var requestStartTimes: [String: Date] = [:]
    private let requestQueue = DispatchQueue(label: "network.logger.queue", attributes: .concurrent)
    
    // MARK: - 日志开关检查
    private var shouldLog: Bool {
        #if DEBUG
        return NetworkLoggerConfig.isEnabled && Logger.isEnabled
        #else
        return NetworkLoggerConfig.isEnabled && NetworkLoggerConfig.enableInRelease && Logger.isEnabled
        #endif
    }
    
    // MARK: - 公共日志方法
    
    /// 记录请求开始
    func logRequest(
        url: URL,
        method: HTTPMethod,
        parameters: Parameters? = nil,
        headers: HTTPHeaders = HTTPHeaders(),
        responseType: Any.Type
    ) {
        guard shouldLog else { return }
        
        let requestId = generateRequestId(url: url, method: method)
        
        // 🔧 修复：使用 barrier 确保写操作的线程安全
        requestQueue.async(flags: .barrier) { [weak self] in
            self?.requestStartTimes[requestId] = Date()
        }
        
        let separator = String(repeating: "=", count: 80)
        var logMessage = """
        
        \(separator)
        📤 网络请求开始
        \(separator)
        🔗 URL: \(url.absoluteString)
        🎯 Method: \(method.rawValue)
        📝 Response Type: \(responseType)
        🆔 Request ID: \(requestId)
        ⏰ Time: \(currentTimeString)
        """
        
        if NetworkLoggerConfig.isVerboseMode {
            if let params = parameters, !params.isEmpty {
                logMessage += "\n📋 Parameters:"
                for (key, value) in params {
                    logMessage += "\n   \(key): \(value)"
                }
            } else {
                logMessage += "\n📋 Parameters: 无"
            }
            
            if !headers.isEmpty {
                logMessage += "\n📨 Headers:"
                for header in headers {
                    let headerValue = isSensitiveField(header.name) ? "***" : header.value
                    logMessage += "\n   \(header.name): \(headerValue)"
                }
            }
        }
        
        logMessage += "\n\(separator)"
        
        Logger.log(logMessage, level: .network, category: .network)
    }
    
    /// 记录响应
    func logResponse<T>(
        response: AFDataResponse<T>,
        url: URL,
        method: HTTPMethod
    ) {
        guard shouldLog else { return }
        
        let requestId = generateRequestId(url: url, method: method)
        
        // 🔧 修复：异步计算持续时间和清理，避免阻塞
        requestQueue.async { [weak self] in
            guard let self = self else { return }
            
            let duration = self.calculateDurationUnsafe(for: requestId)
            let isSlowRequest = duration > NetworkLoggerConfig.slowRequestThreshold
            
            let separator = String(repeating: "=", count: 80)
            let durationEmoji = isSlowRequest ? "🐌" : "⚡"
            let statusEmoji = self.getStatusEmoji(response.response?.statusCode)
            
            var logMessage = """
            
            \(separator)
            📥 网络响应
            \(separator)
            🔗 URL: \(url.absoluteString)
            🎯 Method: \(method.rawValue)
            🆔 Request ID: \(requestId)
            ⏰ Time: \(self.currentTimeString)
            \(durationEmoji) Duration: \(String(format: "%.3f", duration))s\(isSlowRequest ? " (慢请求)" : "")
            """
            
            // 状态码信息
            if let httpResponse = response.response {
                let statusCode = httpResponse.statusCode
                logMessage += "\n\(statusEmoji) Status Code: \(statusCode)"
                
                if NetworkLoggerConfig.isVerboseMode {
                    logMessage += "\n📨 Response Headers:"
                    for (key, value) in httpResponse.allHeaderFields {
                        logMessage += "\n   \(key): \(value)"
                    }
                }
            }
            
            // 响应体信息
            if let data = response.data, NetworkLoggerConfig.isVerboseMode {
                logMessage += "\n📊 Response Size: \(self.formatBytes(data.count))"
                
                if let responseBodyString = self.formatResponseBody(data) {
                    logMessage += "\n📄 Response Body:\n\(responseBodyString)"
                }
            }
            
            // 错误信息
            if let error = response.error {
                logMessage += "\n❌ Error: \(error.localizedDescription)"
                logMessage += self.formatNetworkError(error)
            }
            
            logMessage += "\n\(separator)"
            
            // 根据响应状态选择日志级别
            let logLevel: Logger.Level = response.error != nil ? .error :
                                       (response.response?.statusCode ?? 0 >= 400 ? .warning : .success)
            
            // 在主线程输出日志
            DispatchQueue.main.async {
                Logger.log(logMessage, level: logLevel, category: .network)
            }
            
            // 🔧 修复：使用 barrier 清理请求时间记录
            self.requestQueue.async(flags: .barrier) {
                self.requestStartTimes.removeValue(forKey: requestId)
            }
        }
    }
    
    /// 记录成功解析
    func logSuccess(_ message: String, responseType: Any.Type) {
        guard shouldLog else { return }
        Logger.success("✅ \(message) - 类型: \(responseType)", category: .network)
    }
    
    /// 记录警告
    func logWarning(_ message: String, error: Error? = nil) {
        guard shouldLog else { return }
        var logMessage = "⚠️ \(message)"
        if let error = error {
            logMessage += "\n   详情: \(error.localizedDescription)"
        }
        Logger.warning(logMessage, category: .network)
    }
    
    /// 记录错误
    func logError(_ message: String, error: Error) {
        guard shouldLog else { return }
        let logMessage = """
        ❌ \(message)
           错误详情: \(error.localizedDescription)
           错误类型: \(type(of: error))
        """
        Logger.error(logMessage, category: .network)
    }
    
    /// 记录自定义网络消息
    func log(_ message: String, level: Logger.Level = .info) {
        guard shouldLog else { return }
        Logger.log(message, level: level, category: .network)
    }
    
    /// 记录网络配置信息
    func logNetworkConfig(_ config: [String: Any], title: String = "网络配置") {
        guard shouldLog else { return }
        Logger.logJSON(config, title: title, category: .network)
    }
    
    /// 记录网络统计信息
    func logNetworkStats() {
        guard shouldLog else { return }
        
        requestQueue.async { [weak self] in
            guard let self = self else { return }
            
            let activeRequests = self.requestStartTimes.count
            let oldestRequest = self.requestStartTimes.values.min()
            let oldestDuration = oldestRequest.map { Date().timeIntervalSince($0) }
            
            let stats = [
                "activeRequests": activeRequests,
                "oldestRequestDuration": oldestDuration?.description ?? "N/A",
                "configEnabled": NetworkLoggerConfig.isEnabled,
                "verboseMode": NetworkLoggerConfig.isVerboseMode
            ]
            
            DispatchQueue.main.async {
                Logger.logJSON(stats, title: "网络统计信息", category: .network)
            }
        }
    }
}

// MARK: - 私有辅助方法
private extension NetworkLogger {
    
    /// 当前时间字符串
    var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
    
    /// 生成请求ID
    func generateRequestId(url: URL, method: HTTPMethod) -> String {
        // 🔧 修复：添加 nil 检查和更安全的哈希生成
        guard !url.absoluteString.isEmpty else {
            return "INVALID-\(Date().timeIntervalSince1970)"
        }
        
        let urlHash = abs(url.absoluteString.hashValue)
        let methodPrefix = method.rawValue.prefix(3).uppercased()
        let timestamp = String(Date().timeIntervalSince1970 * 1000).suffix(8) // 使用毫秒时间戳
        return "\(methodPrefix)-\(urlHash)-\(timestamp)"
    }
    
    /// 计算请求持续时间（线程安全版本）
    func calculateDuration(for requestId: String) -> TimeInterval {
        return requestQueue.sync {
            return calculateDurationUnsafe(for: requestId)
        }
    }
    
    /// 计算请求持续时间（非线程安全，仅内部使用）
    func calculateDurationUnsafe(for requestId: String) -> TimeInterval {
        guard let startTime = requestStartTimes[requestId] else {
            return 0
        }
        return Date().timeIntervalSince(startTime)
    }
    
    /// 检查是否为敏感字段
    func isSensitiveField(_ fieldName: String) -> Bool {
        let lowercasedName = fieldName.lowercased()
        return NetworkLoggerConfig.sensitiveFields.contains { keyword in
            lowercasedName.contains(keyword)
        }
    }
    
    /// 获取状态码对应的emoji
    func getStatusEmoji(_ statusCode: Int?) -> String {
        guard let code = statusCode else { return "❓" }
        
        switch code {
        case 200..<300:
            return "✅"
        case 300..<400:
            return "🔄"
        case 400..<500:
            return "⚠️"
        case 500...:
            return "❌"
        default:
            return "❓"
        }
    }
    
    /// 格式化字节数
    func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    /// 格式化响应体
    func formatResponseBody(_ data: Data) -> String? {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return "[二进制数据，无法显示]"
        }
        
        // 尝试格式化JSON
        let formattedJson = formatJsonString(jsonString) ?? jsonString
        
        // 如果设置了最大长度限制且内容超长，则截断
        if NetworkLoggerConfig.maxResponseBodyLength > 0 &&
           formattedJson.count > NetworkLoggerConfig.maxResponseBodyLength {
            return String(formattedJson.prefix(NetworkLoggerConfig.maxResponseBodyLength)) +
                   "\n... (内容被截断，总长度: \(formattedJson.count) 字符)"
        }
        
        return formattedJson
    }
    
    /// 格式化JSON字符串
    func formatJsonString(_ jsonString: String) -> String? {
        guard let jsonData = jsonString.data(using: .utf8) else { return nil }
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
            let prettyJsonData = try JSONSerialization.data(
                withJSONObject: jsonObject,
                options: [.prettyPrinted, .sortedKeys]
            )
            return String(data: prettyJsonData, encoding: .utf8)
        } catch {
            // JSON 解析失败，返回原始字符串
            return nil
        }
    }
    
    /// 格式化网络错误信息
    func formatNetworkError(_ error: AFError) -> String {
        var errorDetails = ""
        
        switch error {
        case .responseValidationFailed(let reason):
            errorDetails += "\n   验证失败: \(reason)"
        case .responseSerializationFailed(let reason):
            errorDetails += "\n   序列化失败: \(reason)"
        case .requestAdaptationFailed(let error):
            errorDetails += "\n   请求适配失败: \(error.localizedDescription)"
        case .requestRetryFailed(let retryError, let originalError):
            errorDetails += "\n   重试失败: \(retryError.localizedDescription)"
            errorDetails += "\n   原始错误: \(originalError.localizedDescription)"
        case .sessionTaskFailed(let error):
            errorDetails += "\n   会话任务失败: \(error.localizedDescription)"
        default:
            break
        }
        
        return errorDetails
    }
}

// MARK: - 便捷扩展方法
extension NetworkLogger {
    
    /// 记录API调用开始
    func logAPICall(
        _ apiName: String,
        url: URL,
        method: HTTPMethod,
        parameters: Parameters? = nil
    ) {
        log("🚀 API调用开始: \(apiName)", level: .info)
        logRequest(url: url, method: method, parameters: parameters, responseType: Data.self)
    }
    
    /// 记录API调用成功
    func logAPISuccess<T>(_ apiName: String, result: T) {
        if let jsonEncodable = result as? Encodable {
            // 如果结果可以编码为JSON，则使用JSON格式
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(AnyEncodable(jsonEncodable))
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                Logger.logJSON(jsonObject, title: "API调用成功: \(apiName)", category: .network)
                return
            } catch {
                // JSON编码失败，降级到普通日志
                Logger.warning("JSON编码失败: \(error.localizedDescription)", category: .network)
            }
        }
        
        Logger.success("API调用成功: \(apiName) - 结果: \(result)", category: .network)
    }
    
    /// 记录API调用失败
    func logAPIFailure(_ apiName: String, error: Error) {
        logError("API调用失败: \(apiName)", error: error)
    }
}

// MARK: - 辅助类型
private struct AnyEncodable: Encodable {
    private let encodable: Encodable
    
    init(_ encodable: Encodable) {
        self.encodable = encodable
    }
    
    func encode(to encoder: Encoder) throws {
        try encodable.encode(to: encoder)
    }
}
