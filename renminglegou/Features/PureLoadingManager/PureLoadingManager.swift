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
    
    private init() {}
    
    /// 显示Loading
    func showLoading(style: LoadingStyle = .spinner) {
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
    func showAlert(message: String, type: AlertType = .info) {
        hideLoading()
        alertMessage = message
        alertType = type
        
        // 3秒后自动隐藏
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                self.alertMessage = nil
            }
        }
    }
    
    /// 显示成功提示
    func showSuccess(message: String) {
        showAlert(message: message, type: .success)
    }
    
    /// 显示错误提示
    func showError(message: String) {
        showAlert(message: message, type: .error)
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
            
            // 顶部提示消息
            if let alertMessage = loadingManager.alertMessage {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: loadingManager.alertType.icon)
                            .foregroundColor(loadingManager.alertType.color)
                            .font(.title2)
                        
                        Text(alertMessage)
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.85))
                    )
                    .padding(.horizontal)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loadingManager.isShowingLoading)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: loadingManager.alertMessage)
    }
}
