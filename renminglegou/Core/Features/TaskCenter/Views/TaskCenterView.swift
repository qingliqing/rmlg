//
//  TaskCenterView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct TaskCenterView: View {
    @StateObject private var viewModel = TaskCenterViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                // Main content
                mainContent
                
                // Alert overlays
                alertOverlays
            }
            .navigationTitle("签到中心")
            .navigationBarTitleDisplayMode(.large)
            .alert("提示", isPresented: $viewModel.showError) {
                Button("确定") { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .alert("成功", isPresented: $viewModel.showSuccessAlert) {
                Button("确定") { }
            } message: {
                Text("任务完成，奖励已发放！")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading {
            loadingView
        } else {
            contentScrollView
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("加载中...")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Content Scroll View
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Header
                TaskCenterHeaderView()
                    .padding(.top, 12)
                
                // Daily task section
                dailyTaskSection
                
                // Activities section
                activitiesSection
            }
            .padding(.bottom, 20)
        }
        .refreshable {
            viewModel.loadData()
        }
    }
    
    // MARK: - Daily Task Section
    @ViewBuilder
    private var dailyTaskSection: some View {
        if let taskInfo = viewModel.taskInfo {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "每日任务", subtitle: "完成任务获得奖励")
                
                TaskCenterDailyTaskCell(
                    taskInfo: taskInfo,
                    onWatchAd: viewModel.watchAdvertisement,
                    onReceive: viewModel.receiveReward,
                    onGoToShop: viewModel.goToShop,
                    isReceiving: viewModel.isReceiving
                )
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Activities Section
    @ViewBuilder
    private var activitiesSection: some View {
        if !viewModel.activities.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionHeader(title: "活动中心", subtitle: "精彩活动等你参与")
                
                ForEach(viewModel.activities) { activity in
                    TaskCenterActivityCell(activity: activity) {
                        viewModel.handleActivityTap(activity)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Section Header
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - Alert Overlays
    @ViewBuilder
    private var alertOverlays: some View {
        // Service charge alert
        if viewModel.showServiceChargeAlert {
            alertOverlay {
                ServiceChargeAlertView(
                    orderAmount: viewModel.orderAmount,
                    onConfirm: viewModel.handleServiceChargePayment,
                    onCancel: {
                        viewModel.showServiceChargeAlert = false
                    }
                )
            }
        }
        
        // Alipay verification alert
        if viewModel.showAlipayAlert {
            alertOverlay {
                AlipayVerifyAlertView(
                    onConfirm: viewModel.navigateToAlipayVerification,
                    onCancel: {
                        viewModel.showAlipayAlert = false
                    }
                )
            }
        }
    }
    
    // MARK: - Alert Overlay Helper
    private func alertOverlay<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // Dismiss on backdrop tap for certain alerts
                }
            
            // Alert content
            content()
                .padding(.horizontal, 24)
        }
        .zIndex(1000)
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.easeInOut(duration: 0.25), value: viewModel.showServiceChargeAlert)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showAlipayAlert)
    }
}

// MARK: - Preview
struct TaskCenterView_Previews: PreviewProvider {
    static var previews: some View {
        TaskCenterView()
            .preferredColorScheme(.light)
        
        TaskCenterView()
            .preferredColorScheme(.dark)
    }
}
