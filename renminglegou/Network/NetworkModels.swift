//
//  NetworkModels.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/24.
//

import Foundation

// MARK: - 网络请求结果
struct APIResponse<T: Codable>: Codable {
    let msg: String?
    let code: Int
    let data: T?
}

// MARK: - 网络错误类型
enum NetworkError: Error, LocalizedError {
    case invalidURL
    case noData
    case decodingError
    case serverError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .noData:
            return "没有数据"
        case .decodingError:
            return "数据解析错误"
        case .serverError(let message):
            return "服务器错误: \(message)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        }
    }
}

// MARK: - 空响应类型
struct Empty: Codable {}
