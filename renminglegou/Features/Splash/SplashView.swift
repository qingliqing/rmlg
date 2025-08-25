//
//  SplashView.swift
//  renminglegou
//

import SwiftUI
import Network

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

// MARK: - 启动页数据模型
struct SplashData: Codable {
    let id: Int?
    let templateId: Int?
    let createTime: String?
    let remark: String?
    let params: [String: String]?
    let layout: SplashLayout?
    
    // 计算属性，从layout中提取需要的值
    var imageURL: String? {
        return layout?.imgList?.first?.url
    }
    
    var displayDuration: TimeInterval {
        return TimeInterval(layout?.timing ?? 3)
    }
    
    var skipEnabled: Bool {
        return layout?.open ?? true
    }
    
    static let `default` = SplashData(
        id: nil,
        templateId: nil,
        createTime: nil,
        remark: nil,
        params: nil,
        layout: SplashLayout(
            open: true,
            openType: 1,
            timing: 3,
            showCount: "3",
            showType: 1,
            imgList: nil
        )
    )
}

struct SplashLayout: Codable {
    let open: Bool?
    let openType: Int?
    let timing: Int?
    let showCount: String?
    let showType: Int?
    let imgList: [SplashImage]?
}

struct SplashImage: Codable {
    let url: String?
    let link: SplashLink?
}

struct SplashLink: Codable {
    let linkName: String?
    let linkUrl: String?
}

// MARK: - 启动页API
enum SplashAPI {
    case getSplashConfig
    
    var path: String {
        switch self {
        case .getSplashConfig:
            return "system/api/config/start"
        }
    }
}

// MARK: - 启动页视图
struct SplashView: View {
    @State private var splashData: SplashData
    @State private var remainingTime: TimeInterval = 0
    @State private var showWebView = false
    @State private var isLoading = true
    @State private var timer: Timer?
    @StateObject private var networkMonitor = NetworkMonitor()
    @StateObject private var splashCache = SplashCache.shared
    
    // 缓存图片作为计算属性，确保实时获取
    private var cachedImage: UIImage? {
        splashCache.getCachedImage()
    }
    
    // 初始化时就加载缓存数据，避免白屏
    init() {
        if let cachedData = SplashCache.shared.getCachedSplashData() {
            _splashData = State(initialValue: cachedData)
        } else {
            _splashData = State(initialValue: SplashData.default)
        }
    }
    
    var body: some View {
        ZStack {
            if showWebView {
                ContentView()
                    .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            } else {
                splashContent
            }
        }
        .onAppear {
            setupSplashScreen()
        }
        .onReceive(networkMonitor.$isConnected) { isConnected in
            if isConnected && isLoading {
                fetchSplashData()
            }
        }
    }
    
    private var splashContent: some View {
        GeometryReader { geometry in
            ZStack {
                // 背景图片
                backgroundImageView(geometry: geometry)
            }
        }
        .ignoresSafeArea(.all)
    }
    
    // 抽离背景图片视图，优化显示逻辑
    @ViewBuilder
    private func backgroundImageView(geometry: GeometryProxy) -> some View {
        if let cachedImage = cachedImage {
            // 有缓存图片时，立即显示缓存图片
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        } else if let imageURL = splashData.imageURL, !imageURL.isEmpty {
            // 没有缓存但有服务器图片URL时，异步加载
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                case .failure(_), .empty:
                    // 加载失败或空状态时显示默认图片
                    defaultSplashImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                @unknown default:
                    defaultSplashImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        } else {
            // 没有图片URL时显示默认图片
            defaultSplashImage
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var defaultSplashImage: some View {
        ZStack {
            // 白色背景填满屏幕
            Color.white
                .ignoresSafeArea(.all)
            Image("launch_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    private func setupSplashScreen() {
        // 如果已经有缓存数据，直接开始倒计时
        if splashCache.getCachedSplashData() != nil {
            isLoading = false
            startCountdown()
        }
        
        // 如果有网络连接，获取最新数据（可能会更新缓存）
        if networkMonitor.isConnected {
            fetchSplashData()
        } else if splashCache.getCachedSplashData() == nil {
            // 没有网络且没有缓存时，使用默认配置
            isLoading = false
            startCountdown()
        }
    }
    
    private func fetchSplashData() {
        isLoading = true
        
        Task {
            do {
                // 使用现有的NetworkManager获取启动页数据
                let data = try await NetworkManager.shared.get(SplashAPI.getSplashConfig.path, type: SplashData.self)
                
                await MainActor.run {
                    // 检查是否需要更新缓存
                    let needsUpdate = !splashCache.isCacheValid(for: data)
                    
                    if needsUpdate {
                        self.splashData = data
                        
                        // 如果有图片URL，下载并缓存
                        if let imageURL = data.imageURL, !imageURL.isEmpty {
                            cacheImageAndData(data, imageURL: imageURL)
                        } else {
                            // 没有图片时只缓存配置数据
                            splashCache.cacheSplashData(data, image: nil)
                        }
                    }
                    
                    self.isLoading = false
                    startCountdown()
                }
            } catch {
                print("获取启动页数据失败: \(error)")
                
                await MainActor.run {
                    // 网络失败时，如果没有缓存数据才使用默认配置
                    if splashCache.getCachedSplashData() == nil {
                        self.splashData = SplashData.default
                    }
                    self.isLoading = false
                    startCountdown()
                }
            }
        }
    }
    
    // 缓存图片和数据的方法
    private func cacheImageAndData(_ splashData: SplashData, imageURL: String) {
        guard let url = URL(string: imageURL) else {
            // 图片URL无效时只缓存配置数据
            splashCache.cacheSplashData(splashData, image: nil)
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        splashCache.cacheSplashData(splashData, image: image)
                        // 缓存完成后，视图会自动刷新，因为使用了计算属性
                    }
                } else {
                    await MainActor.run {
                        splashCache.cacheSplashData(splashData, image: nil)
                    }
                }
            } catch {
                print("缓存图片失败: \(error)")
                await MainActor.run {
                    splashCache.cacheSplashData(splashData, image: nil)
                }
            }
        }
    }
    
    private func startCountdown() {
        remainingTime = splashData.displayDuration
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 0.1
            } else {
                enterWebView()
            }
        }
    }
    
    private func skipSplash() {
        timer?.invalidate()
        timer = nil
        enterWebView()
    }
    
    private func enterWebView() {
        timer?.invalidate()
        timer = nil
        
        withAnimation {
            showWebView = true
        }
    }
}

// MARK: - 网络监控类
class NetworkMonitor: ObservableObject {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var isConnected = false
    
    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

#Preview {
    SplashView()
}
