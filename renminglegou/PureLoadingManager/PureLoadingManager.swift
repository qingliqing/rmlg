// 纯SwiftUI Loading方案 - 无需第三方依赖
import SwiftUI

// MARK: - 纯SwiftUI Loading管理器
@MainActor
class PureLoadingManager: ObservableObject {
    static let shared = PureLoadingManager()
    
    @Published var isShowingLoading = false
    @Published var loadingStyle: LoadingStyle = .spinner
    @Published var alertMessage: String?
    @Published var alertType: AlertType = .success
    @Published var alertPosition: AlertPosition = .top
    
    // 定时器管理
    private var hideAlertTimer: Timer?
    private var alertId: UUID? // 用于标识当前提示消息，防止被错误清除
    
    enum LoadingStyle {
        case spinner          // 原生旋转
        case dots            // 跳动圆点
        case pulse           // 脉冲圆形
        case bars            // 跳动条形
        case circle          // 圆环旋转
    }
    
    enum AlertType {
        case success
        case error
        case info
        
        var color: Color {
            switch self {
            case .success: return .green
            case .error: return .red
            case .info: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    enum AlertPosition {
        case top
        case center
        case bottom
        
        var transition: AnyTransition {
            switch self {
            case .top:
                return .move(edge: .top).combined(with: .opacity)
            case .center:
                return .scale.combined(with: .opacity)
            case .bottom:
                return .move(edge: .bottom).combined(with: .opacity)
            }
        }
    }
    
    private init() {}
    
    /// 显示Loading
    func showLoading(style: LoadingStyle = .spinner) {
        // 先取消任何正在显示的提示消息
        cancelAlert()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingLoading = true
            loadingStyle = style
        }
    }
    
    /// 隐藏Loading
    func hideLoading() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingLoading = false
        }
    }
    
    /// 显示提示消息
    func showAlert(message: String,
                   type: AlertType = .info,
                   position: AlertPosition = .top,
                   duration: TimeInterval = 3.0) {
        // 先隐藏Loading
        hideLoading()
        
        // 取消之前的定时器
        cancelAlert()
        
        // 生成新的消息ID
        let newAlertId = UUID()
        alertId = newAlertId
        
        // 设置新的提示消息
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            alertMessage = message
            alertType = type
            alertPosition = position
        }
        
        // 设置自动隐藏定时器 - 修复Swift 6并发问题
        hideAlertTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // 只有当前提示消息ID匹配时才隐藏（防止新消息被误清除）
                if self.alertId == newAlertId {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        self.alertMessage = nil
                        self.alertId = nil
                    }
                }
            }
        }
    }
    
    /// 显示成功提示
    func showSuccess(message: String,
                     position: AlertPosition = .top,
                     duration: TimeInterval = 3.0) {
        showAlert(message: message, type: .success, position: position, duration: duration)
    }
    
    /// 显示错误提示
    func showError(message: String,
                   position: AlertPosition = .top,
                   duration: TimeInterval = 3.0) {
        showAlert(message: message, type: .error, position: position, duration: duration)
    }
    
    /// 显示信息提示
    func showInfo(message: String,
                  position: AlertPosition = .top,
                  duration: TimeInterval = 3.0) {
        showAlert(message: message, type: .info, position: position, duration: duration)
    }
    
    /// 手动隐藏提示消息
    func hideAlert() {
        cancelAlert()
        
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            alertMessage = nil
        }
    }
    
    /// 取消当前提示消息和定时器
    private func cancelAlert() {
        hideAlertTimer?.invalidate()
        hideAlertTimer = nil
        alertId = nil
    }
    
    /// 检查是否有提示消息正在显示
    var isShowingAlert: Bool {
        return alertMessage != nil
    }
    
    /// 显示临时成功提示（短时间显示）
    func showQuickSuccess(message: String, position: AlertPosition = .center) {
        showSuccess(message: message, position: position, duration: 1.5)
    }
    
    /// 显示临时错误提示（短时间显示）
    func showQuickError(message: String, position: AlertPosition = .center) {
        showError(message: message, position: position, duration: 1.5)
    }
    
    /// 显示持久化错误提示（需要用户手动关闭或长时间显示）
    func showPersistentError(message: String, position: AlertPosition = .center) {
        showError(message: message, position: position, duration: 5.0)
    }
    
    /// 批量操作时的防抖动方法 - 修复Swift 6并发问题
    func debouncedShowSuccess(message: String, delay: TimeInterval = 0.3) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if !self.isShowingAlert {
                self.showQuickSuccess(message: message)
            }
        }
    }
    
    deinit {
        hideAlertTimer?.invalidate()
        hideAlertTimer = nil
    }
}

// MARK: - 自定义Loading动画组件
struct CustomLoadingIndicator: View {
    let style: PureLoadingManager.LoadingStyle
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            switch style {
            case .spinner:
                SpinnerLoadingView()
            case .dots:
                DotsLoadingView()
            case .pulse:
                PulseLoadingView()
            case .bars:
                BarsLoadingView()
            case .circle:
                CircleLoadingView()
            }
        }
    }
}

// MARK: - 旋转Loading
struct SpinnerLoadingView: View {
    @State private var isRotating = false
    
    var body: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(2.0)
    }
}

// MARK: - 跳动圆点Loading
struct DotsLoadingView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .scaleEffect(animating ? 1.0 : 0.3)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - 脉冲Loading
struct PulseLoadingView: View {
    @State private var isPulsing = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 60, height: 60)
                .scaleEffect(isPulsing ? 1.2 : 0.8)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )
            
            Circle()
                .fill(Color.white)
                .frame(width: 30, height: 30)
                .scaleEffect(isPulsing ? 0.8 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                    value: isPulsing
                )
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - 跳动条形Loading
struct BarsLoadingView: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: 6, height: 30)
                    .scaleEffect(y: animating ? 1.0 : 0.3, anchor: .bottom)
                    .animation(
                        Animation
                            .easeInOut(duration: 0.8)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animating
                    )
            }
        }
        .onAppear {
            animating = true
        }
    }
}

// MARK: - 圆环旋转Loading
struct CircleLoadingView: View {
    @State private var isRotating = false
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.8)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            .frame(width: 50, height: 50)
            .rotationEffect(Angle(degrees: isRotating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1.0).repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - 提示消息内容组件
struct AlertMessageContent: View {
    let message: String
    let type: PureLoadingManager.AlertType
    @ObservedObject private var loadingManager = PureLoadingManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.title2)
            
            Text(message)
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
            
            // 添加关闭按钮（可选）
            Button(action: {
                loadingManager.hideAlert()
            }) {
                Image(systemName: "xmark")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.85))
        )
        .padding(.horizontal)
        .onTapGesture {
            // 点击消息也可以关闭
            loadingManager.hideAlert()
        }
    }
}

// MARK: - 纯SwiftUI Loading视图
struct PureSwiftUILoadingView: View {
    @ObservedObject private var loadingManager = PureLoadingManager.shared
    
    var body: some View {
        ZStack {
            // Loading遮罩
            if loadingManager.isShowingLoading {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        // 可选：点击遮罩关闭Loading（根据需求决定是否保留）
                        // loadingManager.hideLoading()
                    }
                
                VStack(spacing: 0) {
                    CustomLoadingIndicator(style: loadingManager.loadingStyle)
                }
                .padding(30)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.black.opacity(0.8))
                )
                .transition(.scale.combined(with: .opacity))
            }
            
            // 根据位置显示提示消息
            if let alertMessage = loadingManager.alertMessage {
                switch loadingManager.alertPosition {
                case .top:
                    topAlertView(message: alertMessage)
                case .center:
                    centerAlertView(message: alertMessage)
                case .bottom:
                    bottomAlertView(message: alertMessage)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loadingManager.isShowingLoading)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loadingManager.alertMessage != nil)
    }
    
    // MARK: - 位置视图
    
    @ViewBuilder
    private func topAlertView(message: String) -> some View {
        VStack {
            AlertMessageContent(
                message: message,
                type: loadingManager.alertType
            )
            .padding(.top, 50)
            
            Spacer()
        }
        .transition(loadingManager.alertPosition.transition)
    }
    
    @ViewBuilder
    private func centerAlertView(message: String) -> some View {
        VStack {
            Spacer()
            
            AlertMessageContent(
                message: message,
                type: loadingManager.alertType
            )
            
            Spacer()
        }
        .transition(loadingManager.alertPosition.transition)
    }
    
    @ViewBuilder
    private func bottomAlertView(message: String) -> some View {
        VStack {
            Spacer()
            
            AlertMessageContent(
                message: message,
                type: loadingManager.alertType
            )
            .padding(.bottom, 50)
        }
        .transition(loadingManager.alertPosition.transition)
    }
}
