//
//  SplashView.swift
//  renminglegou
//

import SwiftUI
import Combine

// MARK: - 启动页状态枚举
enum SplashState {
    case loading           // 初始加载
    case displaying        // 显示启动页（倒计时 + 预加载广告）
    case showingAd         // 显示开屏广告
    case finished          // 完成，进入主页面
}

// MARK: - 启动页视图
struct SplashView: View {
    @EnvironmentObject private var sdkManager: SDKManager
    @State private var splashData: SplashData
    @State private var remainingTime: TimeInterval = 0
    @State private var splashTimer: Timer?
    @State private var timeoutTimer: Timer?  // 全局超时保护
    @State private var currentState: SplashState = .loading
    @State private var isAdLoaded = false
    @State private var hasAttemptedAdLoad = false  // 防止重复加载广告
    
    @StateObject private var splashCache = SplashCache.shared
    @ObservedObject private var splashAdManager = SplashAdManager.shared
    
    // 广告事件监听取消器
    @State private var adEventCancellables: Set<AnyCancellable> = []
    
    // 配置参数
    private let globalTimeoutDuration: TimeInterval = 10.0  // 全局超时时间
    private let adWaitTimeAfterSplash: TimeInterval = 1.5   // 启动页结束后等待广告的时间
    
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
            initializeSplash()
        }
        .onReceive(sdkManager.$adSDKInitialized) { isInitialized in
            if isInitialized {
                Logger.info("广告SDK初始化完成，开始预加载开屏广告", category: .adSlot)
                handleAdSDKInitialized()
            }
        }
        .onDisappear {
            cleanupSplashView()
        }
    }
    
    @ViewBuilder
    private var splashContainer: some View {
        switch currentState {
        case .loading, .displaying:
            splashContent
            
        case .showingAd:
            splashContent  // 广告在原生层显示
            
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
    
    // MARK: - 主要流程控制
    
    // 初始化启动页
    private func initializeSplash() {
        Logger.info("=== 启动页流程开始 ===", category: .ui)
        
        setupSplashAdManager()
        startGlobalTimeout()  // 启动全局超时保护
        
        // 如果有缓存数据，立即开始显示
        if splashCache.getCachedSplashData() != nil {
            startDisplayPhase()
        } else {
            // 没有缓存，先加载数据
            currentState = .loading
            fetchSplashData()
        }
    }
    
    // 开始显示阶段（启动页倒计时 + 预加载广告）
    private func startDisplayPhase() {
        Logger.info("开始启动页显示阶段", category: .ui)
        currentState = .displaying
        
        // 同时启动两个并行任务
        startSplashCountdown()  // 启动页倒计时
        startAdPreloading()     // 广告预加载
    }
    
    // 启动页倒计时结束的处理
    private func handleSplashCountdownFinished() {
        Logger.info("启动页倒计时结束，检查广告状态", category: .ui)
        
        if isAdLoaded {
            // 广告已加载完成，立即显示
            Logger.success("广告已就绪，立即显示", category: .adSlot)
            showSplashAd()
        } else {
            // 广告未加载完成，等待一小段时间
            Logger.info("广告未就绪，等待 \(adWaitTimeAfterSplash) 秒", category: .adSlot)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + adWaitTimeAfterSplash) {
                if self.currentState == .displaying {
                    if self.isAdLoaded {
                        Logger.success("等待期间广告加载完成，显示广告", category: .adSlot)
                        self.showSplashAd()
                    } else {
                        Logger.info("等待超时，直接进入主页面", category: .adSlot)
                        self.enterMainPage()
                    }
                }
            }
        }
    }
    
    // 显示开屏广告
    private func showSplashAd() {
        guard currentState == .displaying else {
            Logger.warning("状态不正确，无法显示广告", category: .adSlot)
            return
        }
        
        Logger.info("开始显示开屏广告", category: .adSlot)
        currentState = .showingAd
        
        // 广告会自动显示，我们只需要等待关闭事件
    }
    
    // 进入主页面
    private func enterMainPage() {
        guard currentState != .finished else {
            Logger.warning("已经在主页面，避免重复跳转", category: .ui)
            return
        }
        
        Logger.success("=== 进入主页面 ===", category: .ui)
        currentState = .finished
        
        // 清理资源
        cleanupTimersAndResources()
        
        // 跳转到主页面
        let rootUrl = NetworkAPI.baseWebURL
        splashAdManager.setInSplashView(false)
        Router.pushReplace(.webView(url: URL(string: rootUrl)!, title: "首页", showBackButton: false))
    }
    
    // MARK: - 定时器和超时控制
    
    // 启动页倒计时
    private func startSplashCountdown() {
        let duration = splashData.displayDuration
        Logger.info("启动页倒计时开始: \(duration) 秒", category: .ui)
        
        remainingTime = duration
        
        splashTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.remainingTime > 0 {
                self.remainingTime -= 0.1
            } else {
                self.splashTimer?.invalidate()
                self.splashTimer = nil
                self.handleSplashCountdownFinished()
            }
        }
    }
    
    // 全局超时保护
    private func startGlobalTimeout() {
        Logger.info("启动全局超时保护: \(globalTimeoutDuration) 秒", category: .ui)
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: globalTimeoutDuration, repeats: false) { _ in
            Logger.warning("全局超时触发，强制进入主页面", category: .ui)
            self.enterMainPage()
        }
    }
    
    // 清理定时器和资源
    private func cleanupTimersAndResources() {
        splashTimer?.invalidate()
        splashTimer = nil
        
        timeoutTimer?.invalidate()
        timeoutTimer = nil
        
        adEventCancellables.removeAll()
    }
    
    // MARK: - 广告相关
    
    // 设置广告管理器
    private func setupSplashAdManager() {
        Logger.info("设置开屏广告管理器", category: .adSlot)
        
        splashAdManager.setInSplashView(true)
        splashAdManager.resetSessionState()
        
        setupAdEventListeners()
    }
    
    // 开始广告预加载
    private func startAdPreloading() {
        // 检查是否已经尝试过加载
        guard !hasAttemptedAdLoad else {
            Logger.info("已经尝试过加载广告，跳过", category: .adSlot)
            return
        }
        
        // 检查SDK是否已初始化
        guard sdkManager.isAdSDKReady else {
            Logger.warning("广告SDK未初始化，无法加载广告", category: .adSlot)
            return
        }
        
        // 只有在displaying状态才加载广告
        guard currentState == .displaying else {
            Logger.info("当前状态(\(currentState.debugDescription))不是displaying，跳过广告加载", category: .adSlot)
            return
        }
        
        // 获取广告位ID
        let adSlotManager = sdkManager.getAdSlotManager()
        guard let adSlotId = adSlotManager.getCurrentSplashAdSlotId() else {
            Logger.warning("未找到开屏广告位ID，跳过广告", category: .adSlot)
            return
        }
        
        Logger.info("开始预加载开屏广告，广告位ID: \(adSlotId)", category: .adSlot)
        hasAttemptedAdLoad = true
        
        SplashAdManager.shared.loadSplashAd()
    }
    
    // 处理广告SDK初始化完成
    private func handleAdSDKInitialized() {
        Logger.success("广告SDK初始化完成", category: .adSlot)
        
        // 只有在displaying状态且未尝试加载广告时才加载
        if currentState == .displaying && !hasAttemptedAdLoad {
            Logger.info("启动页显示中且未加载广告，开始预加载", category: .adSlot)
            startAdPreloading()
        } else if currentState == .finished {
            Logger.info("已进入主页面，不再加载开屏广告", category: .adSlot)
        } else if hasAttemptedAdLoad {
            Logger.info("已经尝试过加载广告，跳过", category: .adSlot)
        } else {
            Logger.info("当前状态: \(currentState.debugDescription)", category: .adSlot)
        }
    }
    
    // 设置广告事件监听
    private func setupAdEventListeners() {
        adEventCancellables.removeAll()
        
        // 广告加载成功
        NotificationCenter.default.publisher(for: .splashAdLoadSuccess)
            .sink { _ in
                Logger.success("开屏广告预加载成功", category: .adSlot)
                self.isAdLoaded = true
            }
            .store(in: &adEventCancellables)
        
        // 广告加载失败
        NotificationCenter.default.publisher(for: .splashAdLoadFailed)
            .sink { _ in
                Logger.warning("开屏广告预加载失败", category: .adSlot)
                self.isAdLoaded = false
                // 不做其他处理，让启动页正常结束
            }
            .store(in: &adEventCancellables)
        
        // 广告开始展示
        NotificationCenter.default.publisher(for: .splashAdDidShow)
            .sink { _ in
                Logger.success("开屏广告开始展示", category: .adSlot)
            }
            .store(in: &adEventCancellables)
        
        // 广告关闭
        NotificationCenter.default.publisher(for: .splashAdDidClose)
            .sink { _ in
                Logger.info("开屏广告关闭", category: .adSlot)
                if self.currentState == .showingAd {
                    self.enterMainPage()
                }
            }
            .store(in: &adEventCancellables)
        
        // 广告展示失败
        NotificationCenter.default.publisher(for: .splashAdShowFailed)
            .sink { _ in
                Logger.warning("开屏广告展示失败", category: .adSlot)
                if self.currentState == .showingAd {
                    self.enterMainPage()
                }
            }
            .store(in: &adEventCancellables)
    }
    
    // MARK: - 数据加载
    
    // 获取启动页数据
    private func fetchSplashData() {
        Logger.info("开始获取启动页数据", category: .network)
        
        Task {
            do {
                let data = try await NetworkManager.shared.get(
                    SplashAPI.getSplashConfig.path,
                    type: SplashData.self
                )
                
                await MainActor.run {
                    Logger.success("启动页数据获取成功", category: .network)
                    self.splashData = data
                    
                    // 缓存数据和图片
                    if let imageURL = data.imageURL, !imageURL.isEmpty {
                        self.cacheImageAndData(data, imageURL: imageURL)
                    } else {
                        self.splashCache.cacheSplashData(data, image: nil)
                    }
                    
                    // 开始显示阶段
                    if self.currentState == .loading {
                        self.startDisplayPhase()
                    }
                }
            } catch {
                Logger.error("获取启动页数据失败: \(error.localizedDescription)", category: .network)
                
                await MainActor.run {
                    // 使用默认数据继续
                    if self.currentState == .loading {
                        self.splashData = SplashData.default
                        self.startDisplayPhase()
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
                        self.splashCache.cacheSplashData(splashData, image: image)
                        Logger.success("启动页图片缓存成功", category: .ui)
                    }
                } else {
                    await MainActor.run {
                        self.splashCache.cacheSplashData(splashData, image: nil)
                    }
                }
            } catch {
                Logger.error("缓存启动页图片失败: \(error.localizedDescription)", category: .network)
                await MainActor.run {
                    self.splashCache.cacheSplashData(splashData, image: nil)
                }
            }
        }
    }
    
    // MARK: - 生命周期管理
    
    // 清理启动页
    private func cleanupSplashView() {
        Logger.info("清理启动页资源", category: .ui)
        
        cleanupTimersAndResources()
        
        splashAdManager.setInSplashView(false)
        splashAdManager.disableSplashAd()
        splashAdManager.destroyAd()
    }
    
    // MARK: - UI组件
    
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
}

// MARK: - SplashState Extension for Debug
extension SplashState {
    var debugDescription: String {
        switch self {
        case .loading:
            return "加载中"
        case .displaying:
            return "显示启动页"
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
