//
//  CacheManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation

class CacheManager {
    static func getCacheSize() -> String {
        let cacheSize = URLCache.shared.currentDiskUsage
        let sizeInMB = Double(cacheSize) / 1024.0 / 1024.0
        return String(format: "%.2f MB", sizeInMB)
    }
    
    static func cleanCache() {
        URLCache.shared.removeAllCachedResponses()
        
        // 清理临时文件
        let tempDirectory = NSTemporaryDirectory()
        let fileManager = FileManager.default
        
        do {
            let tempFiles = try fileManager.contentsOfDirectory(atPath: tempDirectory)
            for file in tempFiles {
                let filePath = tempDirectory + file
                try fileManager.removeItem(atPath: filePath)
            }
        } catch {
            print("清理临时文件失败: \(error)")
        }
    }
}
