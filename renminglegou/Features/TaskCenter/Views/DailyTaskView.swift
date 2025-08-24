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
                    
                    // 看视频按钮
                    Button(action: {
                        viewModel.watchDailyTaskAdvertisement()
                    }) {
                        Group {
                            if let _ = UIImage(named: "watch_video_button") {
                                Image("watch_video_button")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 32)
                            } else {
                                Text("看广告")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    .disabled(!viewModel.canWatchDailyAd || viewModel.isReceivingTask)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 任务进度
                HStack(spacing: 15) {
                    ForEach(0..<5, id: \.self) { index in
                        ZStack (alignment: .top){
                            // 根据任务完成状态显示不同图片
                            Group {
                                let currentCount = viewModel.todayAdCount
                                
                                if index < currentCount {
                                    // 已完成状态
                                    if let _ = UIImage(named: "task_coin_completed") {
                                        Image("task_coin_completed")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 80)
                                    }
                                } else if index == currentCount && viewModel.canWatchDailyAd {
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
                    if viewModel.canWatchDailyAd && !viewModel.isReceivingTask {
                        viewModel.watchDailyTaskAdvertisement()
                    }
                }) {
                    ZStack(){
                        Image("daily_task_btn_bg")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 250, height: 60)
                        Text("看视频")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!viewModel.canWatchDailyAd || viewModel.isReceivingTask)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, 16)
        .opacity(viewModel.isLoading ? 0.5 : 1.0)
    }
}
