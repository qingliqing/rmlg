//
//  SplashView.swift
//  renminglegou
//

// MARK: - 开屏流程控制器（核心类）
import Foundation
import SwiftUI
import Combine

class SplashFlowController: ObservableObject {
    static let shared = SplashFlowController()
    
    // MARK: - 状态定义
    @Published var currentState: SplashState = .initializing
    @Published var remainingTime: TimeInterval = 0
    @Published var showContent = true
    
    // MARK: - 配置常量
    private let globalTimeout: TimeInterval = 15.0    // 延长全局超时
    private let adWaitTime: TimeInterval = 2.0        // 延长广告等待时间
    private let defaultSplashDuration: TimeInterval = 3.0
    
    // MARK: - 组件
    private var dataLoader: SplashDataLoader?
    private var splashAdManager: SplashAdManager = SplashAdManager.shared
    private var timer: Timer?
    private var timeoutTimer: Timer?
    
    // MARK: - 状态控制
    private var isFlowCompleted = false
    private var isCleaningUp = false
    
    private init() {}
    
    // MARK: - 公开接口
    
    /// 启动流程
    func startFlow() {
        guard currentState == .initializing else {
            Logger.warning("流程已启动，跳过重复调用", category: .ui)
            return
        }
        
        Logger.info("=== 开屏流程启动 ===", category: .ui)
        
        isFlowCompleted = false
        isCleaningUp = false
        setupComponents()
        startGlobalTimeout()
        transitionTo(.loadingData)
    }
    
    /// 手动清理（页面销毁时调用）
    func cleanup() {
        // 如果广告正在展示，不执行清理
        if currentState == .showingAd && !isFlowCompleted {
            Logger.warning("广告正在展示中，延迟清理", category: .ui)
            return
        }
        
        guard !isCleaningUp else {
            Logger.info("清理已在进行中，跳过重复清理", category: .ui)
            return
        }
        
        isCleaningUp = true
        Logger.info("开屏流程清理", category: .ui)
        
        stopAllTimers()
        cleanupAdManager()
        dataLoader = nil
    }
    
    /// 强制完成流程（用于异常情况）
    func forceComplete() {
        Logger.warning("强制完成开屏流程", category: .ui)
        isFlowCompleted = true
        transitionTo(.completed)
    }
    
    /// 检查流程是否完成
    var isCompleted: Bool {
        return isFlowCompleted
    }
    
    // MARK: - 私有方法
    
    private func setupComponents() {
        dataLoader = SplashDataLoader()
        setupAdManager()
    }
    
    private func setupAdManager() {
        splashAdManager.resetSessionState()
        splashAdManager.setInSplashView(true)
        
        // 设置事件回调（替换通知机制）
        splashAdManager.setEventCallback { [weak self] event in
            self?.handleAdEvent(event)
        }
    }
    
    private func handleAdEvent(_ event: SplashAdEvent) {
        switch event {
        case .loadSuccess:
            Logger.success("收到广告加载成功事件", category: .adSlot)
            
        case .loadFailed(let error):
            Logger.warning("广告加载失败: \(error.localizedDescription)", category: .adSlot)
            // 不立即跳转，等待启动页倒计时结束
            
        case .willShow:
            Logger.info("广告即将展示", category: .adSlot)
            
        case .didShow:
            Logger.success("广告已展示", category: .adSlot)
            // 广告开始展示后，停止全局超时计时器
            stopGlobalTimeout()
            
        case .showFailed(let error):
            Logger.warning("广告展示失败: \(error.localizedDescription)", category: .adSlot)
            self.completeFlow()
            
        case .clicked:
            Logger.info("广告被点击", category: .adSlot)
            
        case .closed(let closeType):
            Logger.info("广告关闭: \(closeType)", category: .adSlot)
            self.completeFlow()
            
        case .renderSuccess:
            Logger.success("广告渲染成功", category: .adSlot)
            
        case .renderFailed(let error):
            Logger.warning("广告渲染失败: \(error.localizedDescription)", category: .adSlot)
            
        case .videoPlayFinished:
            Logger.info("广告视频播放完成", category: .adSlot)
            
        case .videoPlayFailed(let error):
            Logger.warning("广告视频播放失败: \(error.localizedDescription)", category: .adSlot)
        }
    }
    
    private func completeFlow() {
        guard !isFlowCompleted else { return }
        
        Logger.info("标记流程完成", category: .ui)
        isFlowCompleted = true
        transitionTo(.completed)
    }
    
    private func cleanupAdManager() {
        // 只有在流程完成后才清理广告管理器
        if isFlowCompleted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.splashAdManager.setInSplashView(false)
                self.splashAdManager.disableSplashAd()
                self.splashAdManager.destroyAd()
                Logger.info("广告管理器清理完成", category: .adSlot)
            }
        }
    }
    
    private func transitionTo(_ newState: SplashState) {
        guard !isCleaningUp else {
            Logger.warning("清理进行中，跳过状态转换", category: .ui)
            return
        }
        
        let oldState = currentState
        currentState = newState
        
        Logger.info("状态转换: \(oldState.description) -> \(newState.description)", category: .ui)
        
        executeCurrentState()
    }
    
    private func executeCurrentState() {
        switch currentState {
        case .initializing:
            break
            
        case .loadingData:
            loadDataAndPrepareAd()
            
        case .displayingSplash(let duration):
            startSplashDisplay(duration: duration)
            
        case .waitingForAd:
            handleWaitingForAd()
            
        case .showingAd:
            showAd()
            
        case .completed:
            navigateToMainPage()
        }
    }
    
    // MARK: - 状态执行逻辑
    
    private func loadDataAndPrepareAd() {
        Task {
            // 并行执行启动页数据加载和广告位初始化
            async let splashDataTask = loadSplashData()
            async let adSlotInitTask: () = ensureAdSlotInitialized()
            
            // 等待启动页数据加载完成
            let splashData = await splashDataTask
            
            await MainActor.run {
                let duration = splashData?.displayDuration ?? self.defaultSplashDuration
                self.transitionTo(.displayingSplash(duration))
            }
            
            // 等待广告位初始化完成后，再预加载广告
            let _ = await adSlotInitTask
            await preloadAd()
        }
    }
    
    private func ensureAdSlotInitialized() async {
        let adSlotManager = AdSlotManager.shared
        
        // 如果已经初始化，直接返回
        if adSlotManager.isInitialized {
            Logger.info("广告位已初始化", category: .adSlot)
            return
        }
        
        // 如果正在初始化，等待完成
        if adSlotManager.isLoading {
            Logger.info("广告位正在初始化中，等待完成", category: .adSlot)
            
            // 轮询等待，最多等待5秒
            let maxWaitTime = 5.0
            let checkInterval = 0.1
            var waitedTime = 0.0
            
            while adSlotManager.isLoading && waitedTime < maxWaitTime {
                try? await Task.sleep(nanoseconds: UInt64(checkInterval * 1_000_000_000))
                waitedTime += checkInterval
            }
            
            if adSlotManager.isInitialized {
                Logger.success("广告位初始化完成", category: .adSlot)
            } else {
                Logger.warning("广告位初始化超时", category: .adSlot)
            }
            return
        }
        
        // 尝试初始化，但不阻塞太久
        Logger.info("开始初始化广告位", category: .adSlot)
        await adSlotManager.initializeOnAppLaunch()
    }
    
    private func loadSplashData() async -> SplashData? {
        do {
            let data = try await dataLoader?.loadSplashData()
            Logger.success("启动页数据加载成功", category: .network)
            return data
        } catch {
            Logger.error("启动页数据加载失败: \(error)", category: .network)
            return nil
        }
    }
    
    private func preloadAd() async {
        // 检查SDK是否就绪
        guard await SDKManager.shared.isAdSDKReady else {
            Logger.warning("广告SDK未就绪，等待初始化", category: .adSlot)
            return
        }
        
        // 使用回调方式加载广告
        splashAdManager.loadSplashAd { result in
            switch result {
            case .success:
                Logger.success("广告预加载成功", category: .adSlot)
                
            case .failure(let error):
                Logger.error("广告预加载失败: \(error.localizedDescription)", category: .adSlot)
            }
        }
    }
    
    private func startSplashDisplay(duration: TimeInterval) {
        remainingTime = duration
        
        Logger.info("启动页倒计时开始: \(duration) 秒", category: .ui)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            if self.remainingTime > 0 {
                self.remainingTime -= 0.1
            } else {
                self.timer?.invalidate()
                self.timer = nil
                Logger.info("启动页倒计时结束", category: .ui)
                self.transitionTo(.waitingForAd)
            }
        }
    }
    
    private func handleWaitingForAd() {
        if splashAdManager.isAdReady {
            // 广告已准备好，立即显示
            Logger.success("广告已就绪，立即显示", category: .adSlot)
            transitionTo(.showingAd)
        } else {
            // 等待广告准备或超时
            Logger.info("广告未就绪，等待 \(adWaitTime) 秒", category: .adSlot)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + adWaitTime) { [weak self] in
                guard let self = self, self.currentState == .waitingForAd else { return }
                
                if self.splashAdManager.isAdReady {
                    Logger.success("等待期间广告加载完成，显示广告", category: .adSlot)
                    self.transitionTo(.showingAd)
                } else {
                    Logger.info("等待超时，直接进入主页面", category: .adSlot)
                    self.completeFlow()
                }
            }
        }
    }
    
    private func showAd() {
        showContent = false  // 隐藏启动页内容，让广告ViewController可见
        
        Logger.info("切换到广告展示模式，隐藏启动页内容", category: .ui)
        
        // 延迟一帧确保UI更新完成
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let success = self.splashAdManager.showSplashAd()
            if !success {
                Logger.error("广告展示失败，进入主页面", category: .adSlot)
                self.completeFlow()
            }
        }
    }
    
    private func navigateToMainPage() {
        Logger.success("=== 进入主页面 ===", category: .ui)
        
        // 延迟导航，确保广告完全关闭
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.cleanup()
            
            // 跳转到主页面
            let rootUrl = NetworkAPI.baseWebURL
            Router.pushReplace(.webView(url: URL(string: rootUrl)!, title: "首页", showBackButton: false))
        }
    }
    
    // MARK: - 定时器管理
    
    private func startGlobalTimeout() {
        Logger.info("启动全局超时保护: \(globalTimeout) 秒", category: .ui)
        
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: globalTimeout, repeats: false) { [weak self] _ in
            Logger.warning("全局超时触发，强制进入主页面", category: .ui)
            self?.forceComplete()
        }
    }
    
    private func stopGlobalTimeout() {
        Logger.info("停止全局超时计时器", category: .ui)
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
    
    private func stopAllTimers() {
        timer?.invalidate()
        timer = nil
        timeoutTimer?.invalidate()
        timeoutTimer = nil
    }
}

// MARK: - 状态枚举
enum SplashState: Equatable {
    case initializing                    // 初始化
    case loadingData                    // 加载数据中
    case displayingSplash(TimeInterval) // 显示启动页（带时长）
    case waitingForAd                   // 等待广告
    case showingAd                      // 显示广告
    case completed                      // 完成
    
    var description: String {
        switch self {
        case .initializing: return "初始化"
        case .loadingData: return "加载数据"
        case .displayingSplash(let duration): return "显示启动页(\(String(format: "%.1f", duration))s)"
        case .waitingForAd: return "等待广告"
        case .showingAd: return "显示广告"
        case .completed: return "完成"
        }
    }
}

// MARK: - 数据加载器
class SplashDataLoader {
    func loadSplashData() async throws -> SplashData {
        let data = try await NetworkManager.shared.get(
            SplashAPI.getSplashConfig.path,
            type: SplashData.self
        )
        
        // 缓存数据和图片
        if let imageURL = data.imageURL, !imageURL.isEmpty {
            await cacheImage(from: imageURL, with: data)
        } else {
            await MainActor.run {
                SplashCache.shared.cacheSplashData(data, image: nil)
            }
        }
        
        return data
    }
    
    private func cacheImage(from imageURL: String, with splashData: SplashData) async {
        guard let url = URL(string: imageURL) else {
            await MainActor.run {
                SplashCache.shared.cacheSplashData(splashData, image: nil)
            }
            return
        }
        
        do {
            let (imageData, _) = try await URLSession.shared.data(from: url)
            if let image = UIImage(data: imageData) {
                await MainActor.run {
                    SplashCache.shared.cacheSplashData(splashData, image: image)
                    Logger.success("启动页图片缓存成功", category: .ui)
                }
            } else {
                await MainActor.run {
                    SplashCache.shared.cacheSplashData(splashData, image: nil)
                }
            }
        } catch {
            Logger.error("缓存启动页图片失败: \(error)", category: .network)
            await MainActor.run {
                SplashCache.shared.cacheSplashData(splashData, image: nil)
            }
        }
    }
}

// MARK: - SwiftUI 视图（完全优化）
struct SplashView: View {
    @StateObject private var flowController = SplashFlowController.shared
    @StateObject private var splashCache = SplashCache.shared
    @State private var hasAppeared = false
    
    var body: some View {
        ZStack {
            splashContent
        }
        .onAppear {
            // 防止重复触发
            if !hasAppeared {
                hasAppeared = true
                Logger.info("SplashView appeared", category: .ui)
                flowController.startFlow()
            }
        }
        .onDisappear {
            // 只有在流程真正完成时才清理
            if flowController.isCompleted {
                Logger.info("SplashView disappeared - 流程已完成", category: .ui)
                flowController.cleanup()
            } else {
                Logger.info("SplashView disappeared - 流程未完成，暂不清理", category: .ui)
            }
        }
        // 监听广告SDK初始化状态
        .onReceive(SDKManager.shared.$adSDKInitialized) { isInitialized in
            if isInitialized && flowController.currentState == .loadingData {
                Logger.info("广告SDK初始化完成，当前在加载阶段", category: .adSlot)
            }
        }
    }
    
    private var splashContent: some View {
        GeometryReader { geometry in
            backgroundImageView(geometry: geometry)
        }
        .ignoresSafeArea(.all)
    }
    
    @ViewBuilder
    private func backgroundImageView(geometry: GeometryProxy) -> some View {
        if let cachedImage = splashCache.getCachedImage() {
            Image(uiImage: cachedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        } else {
            // 默认启动图
            ZStack {
                Color.white.ignoresSafeArea(.all)
                Image("launch_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
    }
}
