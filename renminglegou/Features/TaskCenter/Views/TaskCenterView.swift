//
//  TaskCenterView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI
import PopupView

struct TaskCenterView: View {
    @EnvironmentObject var navigationManager: NavigationManager
    @StateObject private var viewModel = TaskCenterViewModel()
    @State private var selectedTab: TaskTab = .daily
    @Environment(\.presentationMode) var presentationMode
    @State private var showRewardPopup = false
    
    var body: some View {
        ZStack {
            // Background image
            Image("task_center_bg")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    bannerView
                    taskContentView
                }
                .padding(.top, 20)
                .padding(.horizontal, 4)
            }
        }
        .padding(.top, DeviceConsts.totalHeight + 20)
        .navigationTitle("任务中心")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 32, height: 32)
                    .foregroundColor(.white)
                    .padding(.horizontal, 0)
                    .padding(.vertical, 6)
            }
        )
        .onAppear {
            setupNavigationBarAppearance()
            // 设置默认选中的tab
            if let firstTab = availableTabs.first {
                selectedTab = firstTab
            }
        }
        .onChange(of: viewModel.isLoading) { _ in
            // 当任务配置加载完成后，确保选中的tab是有效的
            if !viewModel.isLoading && !availableTabs.contains(selectedTab), let firstTab = availableTabs.first {
                selectedTab = firstTab
            }
        }
        .popup(
            isPresented: $showRewardPopup,
            view: {
                RewardPopupView(
                    task: viewModel.swipeTask,
                    onStartAction: {
                        viewModel.swipeVM.watchRewardAd()
                    }
                )
                .ignoresSafeArea(.container, edges: .bottom)
            },
            customize: { params in
                params
                    .type(.floater(verticalPadding: 0, horizontalPadding: 0, useSafeAreaInset: false))
                    .backgroundColor(.black.opacity(0.3))
                    .position(.bottom)
                    .dragToDismiss(false)
                    .closeOnTap(false)
                    .closeOnTapOutside(true)
                    .allowTapThroughBG(false)
            }
        )
    }
    
    @ViewBuilder
    private var bannerView: some View {
        BannerAdView(slotId: "103585837")
            .frame(height: 160)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var taskContentView: some View {
        VStack(spacing: 16) {
            // 动态生成 Tab 按钮
            if !availableTabs.isEmpty {
                HStack(spacing: 30) {
                    ForEach(availableTabs, id: \.self) { tab in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedTab = tab
                            }
                        }) {
                            ZStack {
                                Image(selectedTab == tab ? tab.selectedImageName : tab.normalImageName)
                                    .resizable()
                                    .renderingMode(.original)
                                    .scaledToFit()
                                
                                Text(getTabTitle(for: tab))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .frame(height: 60)
                .padding(.horizontal, 16)
                
                // 动态显示对应的任务内容
                TabView(selection: $selectedTab) {
                    ForEach(availableTabs, id: \.self) { tab in
                        getTaskView(for: tab)
                            .tag(tab)
                    }
                }
                .frame(height: 300)
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: selectedTab)
            } else {
                // 加载状态或无数据状态
                if viewModel.isLoading {
                    ProgressView("正在加载任务配置...")
                        .frame(height: 300)
                        .foregroundColor(.white)
                } else {
                    Text("暂无可用任务")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(height: 300)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取可用的tab列表（基于任务配置）
    private var availableTabs: [TaskTab] {
        guard let tasks = viewModel.adConfig?.tasks else { return [] }
        
        let tabs = tasks.compactMap { task -> TaskTab? in
            switch task.id {
            case 1: return .daily
            case 2: return .swipe
            case 3: return .brand
            default: return nil
            }
        }
        
        // 按照任务的sortOrder排序
        return tabs.sorted { tab1, tab2 in
            let task1 = viewModel.adConfig?.tasks?.first { getTaskId(for: tab1) == $0.id }
            let task2 = viewModel.adConfig?.tasks?.first { getTaskId(for: tab2) == $0.id }
            
            let order1 = task1?.sortOrder ?? Int.max
            let order2 = task2?.sortOrder ?? Int.max
            
            return order1 < order2
        }
    }
    
    /// 获取tab对应的任务ID
    private func getTaskId(for tab: TaskTab) -> Int {
        switch tab {
        case .daily: return 1
        case .swipe: return 2
        case .brand: return 3
        }
    }
    
    /// 获取tab标题（优先使用配置中的标题）
    private func getTabTitle(for tab: TaskTab) -> String {
        let taskId = getTaskId(for: tab)
        
        if let task = viewModel.adConfig?.tasks?.first(where: { $0.id == taskId }),
           let taskName = task.taskName?.displayText,
           !taskName.isEmpty {
            return taskName
        }
        
        // 降级使用默认标题
        return tab.title
    }
    
    /// 获取对应的任务视图
    @ViewBuilder
    private func getTaskView(for tab: TaskTab) -> some View {
        switch tab {
        case .daily:
            DailyTaskView(viewModel: viewModel)
        case .swipe:
            SwipeTaskView(
                viewModel: viewModel,
                onShowRewardPopup: {
                    showRewardPopup = true
                }
            )
        case .brand:
            BrandTaskView(viewModel: viewModel) {
                if viewModel.brandTask?.hasJumpLink ?? false,
                   let urlString = viewModel.brandTask?.jumpLink
                {
                    // 获取用户 token 并进行 URL 编码
                    let userToken = UserModel.shared.token
                    let encodedToken = userToken.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? userToken
                    
                    // 替换占位符
                    let finalURLString = urlString.replacingOccurrences(of: "{1}", with: encodedToken)
                    
                    // 跳转
                    if let finalURL = URL(string: finalURLString) {
                        navigationManager.navigateTo(.webView(url: finalURL,showBackButton: true))
                    } else {
                        print("❌ URL 格式错误: \(finalURLString)")
                    }
                }
            }
        }
    }
    
    // MARK: - Setup Navigation Bar Appearance
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 28, weight: .medium)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
