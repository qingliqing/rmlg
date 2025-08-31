//
//  Untitled.swift
//  renminglegou
//
//  Created by Developer on 9/1/25.
//

import Foundation
import UIKit

// MARK: - 启动页缓存管理器
class SplashCache: ObservableObject {
    static let shared = SplashCache()
    private let imageKey = "SplashImageCache"
    private let dataKey = "SplashDataCache"
    
    // 内存缓存，避免重复读取文件
    private var memoryImageCache: UIImage?
    private var memoryCacheValid = false
    
    private init() {
        // 初始化时预加载图片到内存
        preloadImageToMemory()
    }
    
    // 预加载图片到内存缓存
    private func preloadImageToMemory() {
        guard let imagePath = UserDefaults.standard.string(forKey: imageKey),
              let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)),
              let image = UIImage(data: imageData) else {
            return
        }
        memoryImageCache = image
        memoryCacheValid = true
    }
    
    // 缓存完整的启动页数据和图片
    func cacheSplashData(_ splashData: SplashData, image: UIImage?) {
        // 缓存配置数据
        if let encodedData = try? JSONEncoder().encode(splashData) {
            UserDefaults.standard.set(encodedData, forKey: dataKey)
        }
        
        // 缓存图片
        if let image = image {
            saveImage(image)
            // 同时更新内存缓存
            memoryImageCache = image
            memoryCacheValid = true
        }
    }
    
    // 获取缓存的启动页数据
    func getCachedSplashData() -> SplashData? {
        guard let data = UserDefaults.standard.data(forKey: dataKey),
              let splashData = try? JSONDecoder().decode(SplashData.self, from: data) else {
            return nil
        }
        return splashData
    }
    
    // 保存图片到本地
    private func saveImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imagePath = documentsPath.appendingPathComponent("splash_cache.jpg")
        
        try? data.write(to: imagePath)
        UserDefaults.standard.set(imagePath.path, forKey: imageKey)
    }
    
    // 获取缓存的图片 - 优先使用内存缓存
    func getCachedImage() -> UIImage? {
        // 如果内存缓存有效，直接返回
        if memoryCacheValid, let cachedImage = memoryImageCache {
            return cachedImage
        }
        
        // 内存缓存无效时，从文件读取并更新内存缓存
        guard let imagePath = UserDefaults.standard.string(forKey: imageKey),
              let imageData = try? Data(contentsOf: URL(fileURLWithPath: imagePath)),
              let image = UIImage(data: imageData) else {
            return nil
        }
        
        // 更新内存缓存
        memoryImageCache = image
        memoryCacheValid = true
        
        return image
    }
    
    // 检查缓存是否存在且有效（与当前服务器数据对比）
    func isCacheValid(for serverData: SplashData) -> Bool {
        guard let cachedData = getCachedSplashData() else { return false }
        
        // 比较关键字段判断缓存是否有效
        return cachedData.imageURL == serverData.imageURL &&
               cachedData.displayDuration == serverData.displayDuration &&
               cachedData.skipEnabled == serverData.skipEnabled
    }
    
    // 清除所有缓存
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: dataKey)
        UserDefaults.standard.removeObject(forKey: imageKey)
        
        if let imagePath = UserDefaults.standard.string(forKey: imageKey) {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        
        // 清除内存缓存
        memoryImageCache = nil
        memoryCacheValid = false
    }
}
