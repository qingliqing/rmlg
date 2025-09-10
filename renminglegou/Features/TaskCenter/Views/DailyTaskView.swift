//
//  DailyTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct DailyTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    @ObservedObject var dailyVM: DailyTaskViewModel
    
    var body: some View {
        ZStack(alignment: .top) {
            // 背景图片
            Image("daily_task_card_bg")
                .resizable()
                .scaledToFit()
                .frame(height: 300)
            
            VStack(spacing: 16) {
                // 任务标题和描述
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("每日任务")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 任务进度 - 使用从接口获取的任务总数
                HStack(spacing: 15) {
                    ForEach(0..<maxTaskCount, id: \.self) { index in
                        ZStack (alignment: .top){
                            // 根据任务完成状态显示不同图片
                            Group {
                                let currentCount = viewModel.dailyViewCount
                                
                                if index < currentCount {
                                    // 可观看状态
                                    if let _ = UIImage(named: "task_coin_available") {
                                        Image("task_coin_available")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    }
                                } else {
                                    // 锁定状态
                                    if let _ = UIImage(named: "task_coin_locked") {
                                        Image("task_coin_locked")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    }
                                }
                            }
                            
                            // 视频标识
                            VStack {
                                Text("视频\(index + 1)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(2)
                            }
                            .frame(width: 44, height: 16)
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // 完成按钮
                Button(action: {
                    // 直接调用 dailyVM 的方法（会自动检查冷却时间）
                    viewModel.dailyVM.watchRewardAd()
                }) {
                    ZStack {
                        // 背景图片
                        if let _ = UIImage(named: "daily_task_btn_bg") {
                            Image("daily_task_btn_bg")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 250, height: 60)
                        } else {
                            // 备用按钮样式
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            viewModel.dailyVM.isButtonEnabled ? Color.blue : Color.gray,
                                            viewModel.dailyVM.isButtonEnabled ? Color.purple : Color.gray.opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 250, height: 60)
                        }
                        
                        // 按钮文字 - 使用 dailyVM 的 buttonText（会自动显示倒计时）
                        Text(viewModel.dailyVM.buttonText)
                            .font(.system(size: viewModel.dailyVM.cooldownRemaining > 0 ? 20 : 28, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(viewModel.dailyVM.isButtonEnabled ? 1.0 : 0.7)
                    }
                }
                .disabled(!viewModel.dailyVM.isButtonEnabled)
                .scaleEffect(viewModel.dailyVM.isButtonEnabled ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: viewModel.dailyVM.isButtonEnabled)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 16)
        .opacity(viewModel.isLoading ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
    }
    
    // 获取每日任务的总数量
    private var maxTaskCount: Int {
        return viewModel.dailyTask?.totalAdCount ?? 5
    }
}
