//
//  TaskCenterView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct TaskCenterView: View {
    @StateObject private var viewModel = TaskCenterViewModel()
    @State private var selectedTab: TaskTab = .daily
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            // Background image - 修复背景图片显示
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
            }
            
            // Alert overlays
            alertOverlays
        }
        .padding(.top,Constants.DeviceConsts.totalHeight + 20)
        // 使用普通标题但放大字体来模拟大标题居中效果
        .navigationTitle("任务中心")
        .navigationBarTitleDisplayMode(.inline) // 使用 inline 模式可以居中
        
        // 隐藏默认返回按钮，添加自定义返回按钮
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(leading:
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                
                Image(systemName: "chevron.left")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 32,height: 32)
                    .foregroundColor(.white)
                    .padding(.horizontal, 0)
                    .padding(.vertical, 6)
            }
        )
        
        // 设置导航栏样式
        .onAppear {
            setupNavigationBarAppearance()
            viewModel.loadData()
        }
    }
    
    @ViewBuilder
    private var bannerView: some View {
        Image("task_center_bg")
            .resizable()
            .scaledToFill() // 改为按比例适应
            .frame(maxHeight: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var taskContentView: some View {
         VStack(spacing: 16) {
            // 自定义 Tab 按钮
            HStack(spacing: 20) {
                ForEach(TaskTab.allCases, id: \.self) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    }) {
                        // 如果图片资源不存在，使用文字作为备选
                        ZStack(){
                            
                            Image(selectedTab == tab ? tab.selectedImageName : tab.normalImageName)
                                .resizable() // ✅ 第一步：让图片可调整大小
                                .renderingMode(.original) // ✅ 保持原始渲染
                                .scaledToFit() // ✅
                            
                            
                            Text(tab.title)
                                .foregroundStyle(.white)
                        }
                        
                    }
                }
            }
            .frame(height: 60)
            .padding(.horizontal, 16)
            
            // 使用 TabView 显示内容，但隐藏默认的 tabItem
            TabView(selection: $selectedTab) {
                DailyTaskView(viewModel: viewModel)
                    .tag(TaskTab.daily)
                
                SwipeTaskView(viewModel: viewModel)
                    .tag(TaskTab.swipe)
                
                BrandTaskView(viewModel: viewModel)
                    .tag(TaskTab.brand)
            }
            .frame(height: 300) // 设置内容区域高度
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // 隐藏页面指示器
            .animation(.easeInOut(duration: 0.3), value: selectedTab) // 添加切换动画
        }
    }
    
    // MARK: - Setup Navigation Bar Appearance
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        
        // 设置普通标题字体和颜色 - 放大字体来模拟大标题效果
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 28, weight: .medium) // 放大标题字体
        ]
        
        // 应用外观设置
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    
    // MARK: - Alert Overlays
    @ViewBuilder
    private var alertOverlays: some View {
        EmptyView()
    }
}
