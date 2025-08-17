//
//  TaskCenterViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation
import Combine

@MainActor
class TaskCenterViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var taskInfo: TaskCenterInfoModel?
    @Published var activities: [ActivityModel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var countDown: Int = 0
    @Published var adOpenBv: Int = 0
    @Published var isReceiving = false
    @Published var showSuccessAlert = false
    @Published var showServiceChargeAlert = false
    @Published var showAlipayAlert = false
    @Published var orderAmount = ""
    @Published var downTime: Int = 0
    
    // MARK: - Private Properties
    private let service = TaskCenterService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Business Logic Constants
    private let receiveTaskCaptchaId = "2f5479c434bc408aa6a84f6ca75497bf"
    private let videoTaskCaptchaId = "3e6ace376caa44c2b501dd6a660bece0"
    
    // MARK: - Initialization
    init() {
        loadData()
        setupNotifications()
    }
    
    // MARK: - Public Methods
    
    /// Load all task center data
    func loadData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                async let taskInfo = service.getTaskCenterInfo()
                async let activities = service.getActivityList()
                async let settings = service.getSettings()
                
                let (task, acts, sets) = try await (taskInfo, activities, settings)
                
                self.taskInfo = task
                self.activities = acts
                self.countDown = sets["adIntervalTime"] ?? 0
                self.adOpenBv = sets["adOpenBV"] ?? 0
                self.isLoading = false
                
            } catch {
                handleError(error)
                self.isLoading = false
            }
        }
    }
    
    /// Watch advertisement
    func watchAdvertisement() {
        guard let taskInfo = taskInfo else { return }
        
        // Check countdown timer
        let currentTime = Int(Date().timeIntervalSince1970)
        let timeDiff = currentTime - downTime
        
        if timeDiff < countDown {
            showErrorMessage("下个视频还需等待\(countDown - timeDiff)秒")
            return
        }
        
        Task {
            do {
                // Show advertisement
                try await service.showAdvertisement(advViewNum: taskInfo.advViewNum)
                
                // Handle verification based on settings
                if adOpenBv == 1 {
                    let validate = try await service.showVerificationCode(
                        captchaId: videoTaskCaptchaId,
                        hideCloseButton: true
                    )
                    try await service.finishAdvertisement(
                        taskId: taskInfo.taskId,
                        captchaValidate: validate
                    )
                } else {
                    try await service.finishAdvertisement(
                        taskId: taskInfo.taskId,
                        captchaValidate: ""
                    )
                }
                
                // Update countdown
                downTime = currentTime
                loadData()
                
            } catch {
                handleError(error)
            }
        }
    }
    
    /// Receive task reward
    func receiveReward() {
        guard let taskInfo = taskInfo else { return }
        
        isReceiving = true
        
        Task {
            defer { isReceiving = false }
            
            do {
                if adOpenBv == 1 {
                    let validate = try await service.showVerificationCode(
                        captchaId: receiveTaskCaptchaId,
                        hideCloseButton: false
                    )
                    try await service.finishTask(
                        taskId: taskInfo.taskId,
                        captchaValidate: validate
                    )
                } else {
                    try await service.finishTask(
                        taskId: taskInfo.taskId,
                        captchaValidate: ""
                    )
                }
                
                showSuccessAlert = true
                loadData()
                
            } catch {
                await handleTaskError(error)
            }
        }
    }
    
    /// Navigate to shop
    func goToShop() {
        // Post notification or handle navigation
        NotificationCenter.default.post(name: NSNotification.Name("ToShop"), object: nil)
        print("Navigate to shop")
    }
    
    /// Handle activity item tap
    func handleActivityTap(_ activity: ActivityModel) {
        let url = service.getActivityUrl(activity: activity)
        
        // Navigate to web view or handle URL
        print("Open activity URL: \(url)")
        
        // Record click
        Task {
            try await service.recordActivityClick(activityId: activity.acId)
        }
    }
    
    /// Handle service charge payment
    func handleServiceChargePayment() {
        showServiceChargeAlert = false
        
        Task {
            do {
                let orderId = try await service.createFeeOrder(orderAmount: orderAmount)
                // Navigate to payment page
                print("Navigate to payment with order ID: \(orderId)")
                
                // After successful payment, show Alipay verification
                showAlipayAlert = true
                
            } catch {
                handleError(error)
            }
        }
    }
    
    /// Navigate to Alipay verification
    func navigateToAlipayVerification() {
        showAlipayAlert = false
        let url = service.getAlipayVerificationUrl()
        
        // Navigate to web view for Alipay verification
        print("Navigate to Alipay verification: \(url)")
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        // Listen for advertisement finish notification
        NotificationCenter.default.publisher(for: NSNotification.Name("NoticeAdvertisementWatchFinish"))
            .sink { [weak self] notification in
                Task { @MainActor in
                    self?.handleAdvertisementFinished()
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleAdvertisementFinished() {
        guard let taskInfo = taskInfo else { return }
        
        Task {
            do {
                if adOpenBv == 1 {
                    let validate = try await service.showVerificationCode(captchaId: videoTaskCaptchaId)
                    try await service.finishAdvertisement(
                        taskId: taskInfo.taskId,
                        captchaValidate: validate
                    )
                } else {
                    try await service.finishAdvertisement(
                        taskId: taskInfo.taskId,
                        captchaValidate: ""
                    )
                }
                
                loadData()
                
            } catch {
                handleError(error)
            }
        }
    }
    
    private func handleTaskError(_ error: Error) async {
        if let taskError = error as? TaskCenterError,
           case .alipayNotVerified = taskError {
            await handleAlipayVerification()
        } else {
            handleError(error)
        }
    }
    
    private func handleAlipayVerification() async {
        do {
            orderAmount = try await service.getVerificationCost()
            showServiceChargeAlert = true
        } catch {
            if let taskError = error as? TaskCenterError,
               case .alreadyPaid = taskError {
                showAlipayAlert = true
            } else {
                handleError(error)
            }
        }
    }
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Deinitializer
    deinit {
        cancellables.removeAll()
    }
}
