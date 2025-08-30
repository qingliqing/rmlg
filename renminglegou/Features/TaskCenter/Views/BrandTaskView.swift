//
//  BrandTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct BrandTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    
    // 回调闭包
    let onSubmitCompleted: () -> Void
    
    var body: some View {
        ZStack {
            // 背景图片
            Image("brand_task_card_bg")
                .resizable()
                .scaledToFill()
                .frame(height: 294)
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
        // 回调给上层
        onSubmitCompleted()
    }
}
