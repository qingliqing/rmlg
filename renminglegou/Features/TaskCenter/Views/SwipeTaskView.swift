//
//  SwipeTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct SwipeTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    @State private var isWatchingVideo = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // 背景图片
                Image("swipe_task_card_bg")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack {
                    Spacer()
                    
                    // 开始刷视频按钮
                    Button(action: {
                        handleSwipeAction()
                    }) {
                        
                        Image("swipe_start_btn")
                            .resizable()
                            .scaledToFit()
                        
                    }
                    .frame(width: 250, height: 60)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Private Methods
    private func handleSwipeAction() {
        guard !isWatchingVideo else { return }
        
        isWatchingVideo = true
        
        // 模拟刷视频过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            isWatchingVideo = false
            // 这里可以调用 viewModel 的相关方法处理刷视频结果
            viewModel.handleSwipeVideoResult()
        }
    }
}
