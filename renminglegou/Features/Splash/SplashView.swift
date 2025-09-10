//
//  SplashView.swift
//  renminglegou
//

import SwiftUI
import Combine

// MARK: - 启动页状态枚举
enum SplashState {
    case loading           // 加载启动页数据
    case showingSplash     // 显示启动页（倒计时中）+ 预加载广告
    case adReady           // 广告预加载完成，等待启动页结束
    case showingAd         // 显示开屏广告
    case finished          // 完成，进入主页面
}

// MARK: - 启动页视图
struct SplashView: View {
    @EnvironmentObject private var sdkManager: SDKManager
    @State private var splashData: SplashData
    @State private var remainingTime: TimeInterval = 0
    @State private var isLoading = true
    @State private var timer: Timer?
    @State private var currentState: SplashState = .loading
    @State private var isAdLoaded = false  // 跟踪广告加载状态
    @State private var adLoadStartTime: Date?  // 记录广告加载开始时间
    @State private var isInSplashView: Bool = true  // 是否在当前页面
    
    @StateObject private var splashCache = SplashCache.shared
    @ObservedObject private var splashAdManager = SplashAdManager.shared
    
    // 广告事件监听取消器
    @State private var adEventCancellables: Set<AnyCancellable> = []
    
    private var cachedImage: UIImage? {
        splashCache.getCachedImage()
    }
    
    init() {
        if let cachedData = SplashCache.shared.getCachedSplashData() {
            _splashData = State(initialValue: cachedData)
        } else {
            _splashData = State(initialValue: SplashData.default)
        }
    }
    
    var body: some View {
        ZStack {
            splashContainer
        }
        .onAppear {
            setupSplashAdManager()
            initializeSplash()
        }
        .onDisappear {
            cleanupSplashView()
        }
        .onReceive(sdkManager.$isNetworkConnected) { isConnected in
            if isConnected {
                fetchSplashData()
            }
        }
        .onReceive(sdkManager.$adSDKInitialized) { isInitialized in
            if isInitialized && currentState == .showingSplash && !isAdLoaded {
                Logger.info("广告SDK初始化完成，开始预加载开屏广告", category: .adSlot)
                preloadSplashAd()
            }
        }
    }
    
    @ViewBuilder
    private var splashContainer: some View {
        switch currentState {
        case .loading, .showingSplash, .adReady:
            // 启动页内容，同时可能在后台加载广告
            splashContent
            
        case .showingAd:
            // 开屏广告显示中（黑色背景，广告在上层显示）
            splashContent
            
        case .finished:
            splashContent
        }
    }
    
    // 启动页内容
    private var splashContent: some View {
        GeometryReader { geometry in
            backgroundImageView(geometry: geometry)
        }
        .ignoresSafeArea(.all)
    }
    
    // 设置开屏广告管理器和事件监听
    private func setupSplashAdManager() {
        Logger.info("设置开屏广告管理器", category: .adSlot)
        
        // 通知 SplashAdManager 当前在启动页
        splashAdManager.setInSplashView(true)
        splashAdManager.resetSessionState()
        
        // 监听广告事件
        setupAdEventListeners()
    }
    
    // 设置广告事件监听
    private func setupAdEventListeners() {
        // 清理之前的监听
        adEventCancellables.removeAll()
        
        // 监听广告预加载完成
        NotificationCenter.default.publisher(for: .splashAdLoadSuccess)
            .sink { _ in
                Logger.success("开屏广告预加载完成", category: .adSlot)
                handleAdDidLoad()
            }
            .store(in: &adEventCancellables)
        
        // 监听广告展示
        NotificationCenter.default.publisher(for: .splashAdDidShow)
            .sink { _ in
                Logger.info("开屏广告开始展示", category: .adSlot)
                handleAdDidShow()
            }
            .store(in: &adEventCancellables)
        
        // 监听广告关闭
        NotificationCenter.default.publisher(for: .splashAdDidClose)
            .sink { _ in
                Logger.info("开屏广告关闭，进入主页面", category: .adSlot)
                handleAdDidClose()
            }
            .store(in: &adEventCancellables)
        
        // 监听广告加载失败
        NotificationCenter.default.publisher(for: .splashAdLoadFailed)
            .sink { _ in
                Logger.warning("开屏广告预加载失败", category: .adSlot)
                handleAdLoadFailed()
            }
            .store(in: &adEventCancellables)
        
        // 监听广告展示失败
        NotificationCenter.default.publisher(for: .splashAdShowFailed)
            .sink { _ in
                Logger.warning("开屏广告显示失败", category: .adSlot)
                handleAdShowFailed()
            }
            .store(in: &adEventCancellables)
    }
    
    // 清理启动页资源
    private func cleanupSplashView() {
        Logger.info("清理启动页资源", category: .ui)
        
        // 取消所有广告事件监听
        adEventCancellables.removeAll()
        
        // 停止定时器
        timer?.invalidate()
        timer = nil
        
        // 通知 SplashAdManager 已离开启动页
        splashAdManager.setInSplashView(false)
        splashAdManager.disableSplashAd()
        
        // 销毁可能存在的广告
        splashAdManager.destroyAd()
    }
    
    // 初始化流程
    private func initializeSplash() {
        Logger.info("初始化启动页流程", category: .ui)
        currentState = .loading
        
        // 如果有缓存数据，立即显示
        if let cachedData = splashCache.getCachedSplashData() {
            Logger.info("使用缓存的启动页数据", category: .ui)
            splashData = cachedData
            proceedToNextStep()
        }
        
        // 并行处理：无论是否有缓存，都尝试获取最新数据
        if sdkManager.isNetworkConnected {
            fetchSplashData()
        } else {
            // 没有网络时，给一个短暂的等待时间
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.currentState == .loading {
                    Logger.warning("网络等待超时，继续流程", category: .network)
                    self.proceedToNextStep()
                }
            }
        }
    }
    
    // 统一的流程控制
    private func proceedToNextStep() {
        Logger.debug("当前状态: \(currentState.debugDescription)", category: .ui)
        
        switch currentState {
        case .loading:
            // 数据加载完成，开始显示启动页并预加载广告
            currentState = .showingSplash
            startSplashCountdown()
            
            // 立即开始预加载广告（如果 SDK 已初始化）
            if sdkManager.adSDKInitialized {
                preloadSplashAd()
            }
            
        case .showingSplash:
            // 启动页倒计时结束，检查广告加载状态
            timer?.invalidate()
            timer = nil
            
            if isAdLoaded {
                // 广告已经加载好，立即显示
                Logger.info("广告已预加载完成，立即显示", category: .adSlot)
                showPreloadedAd()
            } else if sdkManager.adSDKInitialized {
                // 广告还在加载，等待一段时间
                Logger.info("广告还在加载，等待完成...", category: .adSlot)
                currentState = .adReady
                waitForAdOrTimeout()
            } else {
                // 没有广告，直接进入主页面
                Logger.info("广告SDK未初始化，直接进入主页面", category: .adSlot)
                currentState = .finished
                enterWebView()
            }
            
        case .adReady:
            // 这个状态由广告加载完成或超时触发
            break
            
        case .showingAd:
            // 这个状态由广告关闭事件触发
            break
            
        case .finished:
            break
        }
    }
    
    // 预加载开屏广告
    private func preloadSplashAd() {
        Logger.info("开始预加载开屏广告", category: .adSlot)
        adLoadStartTime = Date()
        
        // 获取开屏广告位ID
        let adSlotManager = sdkManager.getAdSlotManager()
        guard let adSlotId = adSlotManager.getCurrentSplashAdSlotId() else {
            Logger.warning("未找到开屏广告位ID", category: .adSlot)
            handleAdLoadFailed()
            return
        }
        
        Logger.info("使用开屏广告位ID: \(adSlotId)", category: .adSlot)
        
        // 设置预加载超时（给足够时间）
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
            if !self.isAdLoaded && (self.currentState == .showingSplash || self.currentState == .adReady) {
                Logger.warning("广告预加载超时", category: .adSlot)
                self.handleAdLoadFailed()
            }
        }
        
        SplashAdManager.shared.loadSplashAd()
    }
    
    // 等待广告加载完成或超时
    private func waitForAdOrTimeout() {
        // 给广告一点额外时间完成加载
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.currentState == .adReady {
                if self.isAdLoaded {
                    Logger.info("广告加载完成，开始显示", category: .adSlot)
                    self.showPreloadedAd()
                } else {
                    Logger.warning("等待广告超时，直接进入主页面", category: .adSlot)
                    self.currentState = .finished
                    self.enterWebView()
                }
            }
        }
    }
    
    // 显示已预加载的广告
    private func showPreloadedAd() {
        currentState = .showingAd
        Logger.info("显示预加载的开屏广告", category: .adSlot)
        // 广告已经在 SplashAdManager.loadSplashAd() 中自动显示了
    }
    
    // 跳过启动页
    private func skipSplash() {
        timer?.invalidate()
        timer = nil
        proceedToNextStep()
    }
    
    // 启动页倒计时
    private func startSplashCountdown() {
        Logger.info("开始启动页倒计时: \(splashData.displayDuration)秒", category: .ui)
        remainingTime = splashData.displayDuration
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 0.1
            } else {
                // 倒计时结束，进入下一步
                proceedToNextStep()
            }
        }
    }
    
    // 广告事件处理
    private func handleAdDidLoad() {
        isAdLoaded = true
        
        if let startTime = adLoadStartTime {
            let loadTime = Date().timeIntervalSince(startTime)
            Logger.success("广告预加载完成，耗时: \(String(format: "%.2f", loadTime))秒", category: .adSlot)
        }
        
        // 如果启动页已经结束，立即显示广告
        if currentState == .adReady {
            Logger.info("启动页已结束，立即显示预加载的广告", category: .adSlot)
            showPreloadedAd()
        }
    }
    
    private func handleAdLoadFailed() {
        isAdLoaded = false
        
        // 根据当前状态决定下一步
        if currentState == .showingSplash {
            // 还在启动页，继续倒计时，到时候直接进主页面
            Logger.info("广告预加载失败，启动页结束后直接进入主页面", category: .adSlot)
        } else if currentState == .adReady {
            // 启动页已结束，直接进主页面
            Logger.info("广告加载失败，直接进入主页面", category: .adSlot)
            currentState = .finished
            enterWebView()
        }
    }
    
    private func handleAdDidShow() {
        guard currentState == .showingAd else {
            Logger.warning("广告显示时状态不匹配或已进入主页面", category: .adSlot)
            return
        }
        
        Logger.success("预加载的开屏广告显示成功", category: .adSlot)
    }
    
    private func handleAdDidClose() {
        guard currentState == .showingAd else {
            Logger.warning("广告关闭时状态不匹配或已进入主页面", category: .adSlot)
            return
        }
        
        Logger.info("开屏广告关闭，进入主页面", category: .adSlot)
        currentState = .finished
        enterWebView()
    }
    
    private func handleAdShowFailed() {
        if currentState == .showingAd {
            Logger.warning("预加载广告显示失败，直接进入主页面", category: .adSlot)
            currentState = .finished
            enterWebView()
        }
    }
    
    // 进入主页面
    private func enterWebView() {
        Logger.info("进入主页面", category: .ui)
        
        // 立即标记已离开启动页并清理资源
        cleanupSplashView()
        
        let rootUrl = NetworkAPI.baseWebURL
        
        splashAdManager.setInSplashView(isInSplashView)
        
        Router.pushReplace(.webView(url: URL(string: rootUrl)!, title: "首页", showBackButton: false))
    }
    
    // 背景图片视图
    @ViewBuilder
    private func backgroundImageView(geometry: GeometryProxy) -> some View {
        if let cachedImage = cachedImage {
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        } else if let imageURL = splashData.imageURL, !imageURL.isEmpty {
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                case .failure(_), .empty:
                    defaultSplashImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                @unknown default:
                    defaultSplashImage
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
        } else {
            defaultSplashImage
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    private var defaultSplashImage: some View {
        ZStack {
            Color.white.ignoresSafeArea(.all)
            Image("launch_logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
    
    // 获取启动页数据
    private func fetchSplashData() {
        Logger.info("开始获取启动页数据...", category: .network)
        
        Task {
            do {
                let data = try await NetworkManager.shared.get(
                    SplashAPI.getSplashConfig.path,
                    type: SplashData.self
                )
                
                await MainActor.run {
                    let needsUpdate = !splashCache.isCacheValid(for: data)
                    
                    if needsUpdate {
                        Logger.info("获取到新的启动页数据", category: .network)
                        self.splashData = data
                        
                        if let imageURL = data.imageURL, !imageURL.isEmpty {
                            cacheImageAndData(data, imageURL: imageURL)
                        } else {
                            splashCache.cacheSplashData(data, image: nil)
                        }
                    } else {
                        Logger.info("启动页数据无需更新", category: .network)
                    }
                    
                    // 如果还在加载状态，继续下一步
                    if currentState == .loading {
                        proceedToNextStep()
                    }
                }
            } catch {
                Logger.error("获取启动页数据失败: \(error.localizedDescription)", category: .network)
                
                await MainActor.run {
                    if currentState == .loading {
                        // 使用默认数据或缓存数据继续
                        if splashCache.getCachedSplashData() == nil {
                            self.splashData = SplashData.default
                        }
                        proceedToNextStep()
                    }
                }
            }
        }
    }
    
    // 缓存图片和数据
    private func cacheImageAndData(_ splashData: SplashData, imageURL: String) {
        guard let url = URL(string: imageURL) else {
            splashCache.cacheSplashData(splashData, image: nil)
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        splashCache.cacheSplashData(splashData, image: image)
                        Logger.success("启动页图片缓存成功", category: .ui)
                    }
                } else {
                    await MainActor.run {
                        splashCache.cacheSplashData(splashData, image: nil)
                        Logger.warning("启动页图片解析失败", category: .ui)
                    }
                }
            } catch {
                Logger.error("缓存启动页图片失败: \(error.localizedDescription)", category: .network)
                await MainActor.run {
                    splashCache.cacheSplashData(splashData, image: nil)
                }
            }
        }
    }
}

// MARK: - SplashState Extension for Debug
extension SplashState {
    var debugDescription: String {
        switch self {
        case .loading:
            return "加载中"
        case .showingSplash:
            return "启动页"
        case .adReady:
            return "广告就绪"
        case .showingAd:
            return "显示广告"
        case .finished:
            return "完成"
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(SDKManager.shared)
}
