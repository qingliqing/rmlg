//
//  DailyTaskView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct DailyTaskView: View {
    @ObservedObject var viewModel: TaskCenterViewModel
    
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
                        
                        Text("看广告赚金币")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 任务进度 - 使用从接口获取的任务总数
                HStack(spacing: 15) {
                    ForEach(0..<maxTaskCount, id: \.self) { index in
                        ZStack (alignment: .top){
                            // 根据任务完成状态显示不同图片
                            Group {
                                let currentCount = viewModel.dailyViewCount
                                
                                if index < currentCount {
                                    // 已完成状态
                                    if let _ = UIImage(named: "task_coin_completed") {
                                        Image("task_coin_completed")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    } else {
                                        // 备用UI - 已完成
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.green.opacity(0.8))
                                                .frame(width: 60, height: 80)
                                            
                                            VStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title2)
                                                
                                                Text("已完成")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                } else if index == currentCount && viewModel.canWatchDailyAd {
                                    // 可观看状态
                                    if let _ = UIImage(named: "task_coin_available") {
                                        Image("task_coin_available")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    } else {
                                        // 备用UI - 可观看
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.yellow.opacity(0.8))
                                                .frame(width: 60, height: 80)
                                            
                                            VStack(spacing: 4) {
                                                Image(systemName: "play.circle.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title2)
                                                
                                                Text("可观看")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                } else {
                                    // 锁定状态
                                    if let _ = UIImage(named: "task_coin_locked") {
                                        Image("task_coin_locked")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    } else {
                                        // 备用UI - 锁定
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.gray.opacity(0.6))
                                                .frame(width: 60, height: 80)
                                            
                                            VStack(spacing: 4) {
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(.white)
                                                    .font(.title2)
                                                
                                                Text("锁定")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        }
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
                    if viewModel.canWatchDailyAd {
                        viewModel.watchDailyTaskAd()
                    }
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
                                        gradient: Gradient(colors: [Color.blue, Color.purple]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 250, height: 60)
                        }
                        
                        // 按钮文字 - 根据状态显示不同内容
                        Group {
                            if !viewModel.canWatchDailyAd {
                                Text(viewModel.dailyTaskProgress?.currentViewCount ?? 0 >= maxTaskCount ? "已完成" : "暂不可用")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            } else {
                                Text("看视频")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .disabled(!viewModel.canWatchDailyAd)
                .scaleEffect(viewModel.canWatchDailyAd ? 1.0 : 0.95)
                .animation(.easeInOut(duration: 0.2), value: viewModel.canWatchDailyAd)
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
