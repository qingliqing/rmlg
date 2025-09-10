//
//  SwipeTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI
import PopupView

struct SwipeTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    @ObservedObject var swipeVM: SwipeTaskViewModel  // 直接观察 swipeVM
    @State private var showRewardPopup = false
    @State private var shouldShowAdAfterDismiss = false
    
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
                            // 按钮状态 - 使用 swipeVM 的状态
                            Group {
                                if swipeVM.isTaskCompleted {
                                    Image("swipe_finish_btn")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 60)
                                } else {
                                    Image("swipe_start_btn")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 250, height: 60)
                                }
                            }
                        }
                    }
                    .disabled(!swipeVM.isButtonEnabled)
                    .scaleEffect(swipeVM.isButtonEnabled ? 1.0 : 0.95)
                    .animation(.easeInOut(duration: 0.2), value: swipeVM.isButtonEnabled)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
            }
            .padding(.horizontal, 16)
        }
        .opacity(viewModel.isLoading ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .popup(
            isPresented: $showRewardPopup,
            view: {
                RewardPopupView(
                    task: viewModel.swipeTask,
                    onStartAction: {
                        showRewardPopup = false
                        shouldShowAdAfterDismiss = true  // 设置标记，等待dismiss回调
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
                    .dismissCallback { dismissSource in
                        // 弹窗动画完成后的回调
                        if shouldShowAdAfterDismiss {
                            shouldShowAdAfterDismiss = false
                            // 不需要延迟，因为动画已经完成
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                swipeVM.startSwipeTask()
                            }
                        }
                    }
            }
        )
    }
    
    // MARK: - Private Methods
    private func handleSwipeAction() {
        if swipeVM.isButtonEnabled && !swipeVM.isTaskCompleted {
            showRewardPopup = true
        }
    }
}
