//
//  Logger.swift
//  TaskCenter
//
//  Created by Developer on 2025/9/10.
//

import Foundation
import os.log

/// 统一的日志管理工具，解决print截断问题
class Logger {
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case adSlot = "AdSlot"
        case taskCenter = "TaskCenter"
        case network = "Network"
        case ui = "UI"
        case general = "General"
        
        var osLog: OSLog {
            return OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: self.rawValue)
        }
    }
    
    // MARK: - Log Levels
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
        case network = "🌐"
        case cache = "💾"
        case ad = "🎯"
    }
    
    // MARK: - Configuration
    static var isEnabled = true
    static var maxStringLength = 4000 // 设置最大字符串长度
    
    // MARK: - Public Methods
    
    /// 基础日志方法 - 支持长字符串完整输出
    static func log(
        _ message: Any,
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent
        let timestamp = dateFormatter.string(from: Date())
        let messageString = String(describing: message)
        
        // 如果消息太长，分段输出
        if messageString.count > maxStringLength {
            let chunks = messageString.chunked(into: maxStringLength)
            
            for (index, chunk) in chunks.enumerated() {
                let partInfo = chunks.count > 1 ? " [\(index + 1)/\(chunks.count)]" : ""
                let logMessage = "\(timestamp) \(level.rawValue) [\(category.rawValue)] \(fileName):\(line) \(function)\(partInfo)\n\(chunk)"
                
                // 同时输出到控制台（开发时）
                #if DEBUG
                fputs(logMessage + "\n", stdout)
                fflush(stdout)
                #endif
            }
        } else {
            let logMessage = "\(timestamp) \(level.rawValue) [\(category.rawValue)] \(fileName):\(line) \(function)\n\(messageString)"
            
            #if DEBUG
            fputs(logMessage + "\n", stdout)
            fflush(stdout)
            #endif
        }
    }
    
    /// JSON格式化输出
    static func logJSON(
        _ object: Any,
        title: String = "JSON Data",
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let jsonString = prettyPrintJSON(object)
        let message = """
        \(title):
        \(jsonString)
        """
        
        log(message, level: level, category: category, file: file, function: function, line: line)
    }
    
    /// 数组/字典格式化输出
    static func logCollection<T>(
        _ collection: T,
        title: String = "Collection Data",
        level: Level = .info,
        category: Category = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let description = prettyPrintCollection(collection)
        let message = """
        \(title):
        \(description)
        """
        
        log(message, level: level, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: Any, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    static func info(_ message: Any, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    static func warning(_ message: Any, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    static func error(_ message: Any, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    static func success(_ message: Any, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }
    
    static func network(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .network, category: .network, file: file, function: function, line: line)
    }
    
    static func adSlot(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .ad, category: .adSlot, file: file, function: function, line: line)
    }
    
    // MARK: - Private Helpers
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
    
    /// JSON 格式化
    private static func prettyPrintJSON(_ object: Any) -> String {
        
        if let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return String(describing: object)
    }
    
    /// 集合格式化
    private static func prettyPrintCollection<T>(_ collection: T) -> String {
        let mirror = Mirror(reflecting: collection)
        
        if mirror.displayStyle == .collection {
            let items = mirror.children.enumerated().map { index, child in
                "  [\(index)]: \(child.value)"
            }
            return "[\n\(items.joined(separator: ",\n"))\n]"
        } else if mirror.displayStyle == .dictionary {
            let items = mirror.children.map { child in
                if let key = child.label {
                    return "  \(key): \(child.value)"
                } else {
                    return "  \(child.value)"
                }
            }
            return "{\n\(items.joined(separator: ",\n"))\n}"
        }
        
        return String(describing: collection)
    }
}

// MARK: - String Extension for Chunking

extension String {
    func chunked(into size: Int) -> [String] {
        return stride(from: 0, to: count, by: size).map {
            let start = index(startIndex, offsetBy: $0)
            let end = index(start, offsetBy: min(size, count - $0))
            return String(self[start..<end])
        }
    }
}

// MARK: - 便捷的全局方法

/// 替代 print 的全局方法
func logInfo(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.info(message, file: file, function: function, line: line)
}

func logDebug(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.debug(message, file: file, function: function, line: line)
}

func logError(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.error(message, file: file, function: function, line: line)
}

func logSuccess(_ message: Any, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.success(message, file: file, function: function, line: line)
}

func logJSON(_ object: Any, title: String = "JSON", file: String = #file, function: String = #function, line: Int = #line) {
    Logger.logJSON(object, title: title, file: file, function: function, line: line)
}
