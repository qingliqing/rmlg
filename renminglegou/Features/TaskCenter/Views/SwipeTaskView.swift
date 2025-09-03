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
    let onShowRewardPopup: () -> Void  // 添加回调闭包
    
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
                        ZStack {
                            // 按钮状态
                            Group {
                                if !canStartSwipe {
                                    Image("swipe_finish_btn")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 60)
                                }else {
                                    Image("swipe_start_btn")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 60)
                                }
                            }
                        }
                    }
                    .disabled(!canStartSwipe)
                    .scaleEffect(canStartSwipe ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: canStartSwipe)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
        }
        .opacity(viewModel.isLoading ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    }
    
    // MARK: - Private Methods
    private func handleSwipeAction() {
        if canStartSwipe {
            onShowRewardPopup() // 调用回调
        }
    }
    
    // MARK: - Computed Properties
    
    // 判断是否可以开始刷视频
    private var canStartSwipe: Bool {
        return !isSwipeTaskCompleted && !viewModel.isLoading
    }
    
    // 判断刷视频任务是否已完成
    private var isSwipeTaskCompleted: Bool {
        guard let swipeTask = viewModel.swipeTask else { return false }
        return (viewModel.swipeTaskProgress?.currentViewCount ?? 0) >= swipeTask.totalAdCount
    }
}
