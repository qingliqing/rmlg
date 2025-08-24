//
//  BrandTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct BrandTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    @State private var isSubmitting = false
    
    var body: some View {
        ZStack {
            // 背景图片 - 修复图片显示比例
            Image("brand_task_card_bg")
                .resizable()
                .scaledToFill()
                .frame(height: 294)
                .background(.red)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
            
            VStack(spacing: 16) {
                Spacer()
                
                // 任务提交按钮
                Button(action: {
                    handleBrandTaskAction()
                }) {
                    Image("task_submit_btn")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .frame(width: 250, height: 60)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, 24)
        
    }
    
    // MARK: - Private Methods
    private func handleBrandTaskAction() {
        guard !isSubmitting else { return }
        guard let brandInfo = viewModel.brandTaskInfo, !brandInfo.isCompleted else { return }
        
        isSubmitting = true
        
        // 模拟任务提交过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSubmitting = false
            // 调用 viewModel 的相关方法处理品牌任务
            viewModel.handleBrandTaskResult()
        }
    }
}
