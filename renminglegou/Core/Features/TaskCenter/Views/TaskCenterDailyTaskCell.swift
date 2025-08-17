//
//  TaskCenterDailyTaskCell.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct TaskCenterDailyTaskCell: View {
    let taskInfo: TaskCenterInfoModel
    let onWatchAd: () -> Void
    let onReceive: () -> Void
    let onGoToShop: () -> Void
    let isReceiving: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header section
            headerSection
            
            // Progress section
            progressSection
            
            // Action buttons
            actionButtonsSection
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(taskInfo.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(taskInfo.description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Reward badge
            rewardBadge
        }
    }
    
    // MARK: - Reward Badge
    private var rewardBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: 12))
                .foregroundColor(.yellow)
            
            Text("\(taskInfo.reward)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("观看进度")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(taskInfo.advViewNum)/5")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.blue)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * (CGFloat(taskInfo.advViewNum) / 5.0),
                            height: 8
                        )
                        .animation(.easeInOut(duration: 0.3), value: taskInfo.advViewNum)
                }
            }
            .frame(height: 8)
        }
    }
    
    // MARK: - Action Buttons Section
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // Watch Ad Button
            Button(action: onWatchAd) {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle")
                        .font(.system(size: 14))
                    Text("观看广告")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .foregroundColor(.blue)
            }
            .disabled(taskInfo.advViewNum >= 5)
            
            // Go to Shop Button
            Button(action: onGoToShop) {
                HStack(spacing: 6) {
                    Image(systemName: "cart")
                        .font(.system(size: 14))
                    Text("去商城")
                        .font(.system(size: 14, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )
                .foregroundColor(.green)
            }
            
            // Receive Reward Button
            Button(action: onReceive) {
                HStack(spacing: 6) {
                    if isReceiving {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: taskInfo.isCompleted ? "checkmark.circle" : "gift")
                            .font(.system(size: 14))
                        Text(taskInfo.isCompleted ? "已完成" : "领取")
                            .font(.system(size: 14, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(taskInfo.isCompleted ? Color.gray : Color.orange)
                )
                .foregroundColor(.white)
            }
            .disabled(taskInfo.isCompleted || isReceiving || taskInfo.advViewNum < 5)
        }
    }
}

// MARK: - Preview
struct TaskCenterDailyTaskCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            TaskCenterDailyTaskCell(
                taskInfo: TaskCenterInfoModel(
                    taskId: "task_001",
                    userId: "user_123",
                    adSkipTime: 30,
                    advViewNum: 3,
                    isCompleted: false,
                    title: "每日签到任务",
                    description: "完成每日签到获得金币奖励",
                    reward: 100
                ),
                onWatchAd: {},
                onReceive: {},
                onGoToShop: {},
                isReceiving: false
            )
            
            TaskCenterDailyTaskCell(
                taskInfo: TaskCenterInfoModel(
                    taskId: "task_002",
                    userId: "user_123",
                    adSkipTime: 30,
                    advViewNum: 5,
                    isCompleted: true,
                    title: "已完成任务",
                    description: "任务已完成，奖励已发放",
                    reward: 200
                ),
                onWatchAd: {},
                onReceive: {},
                onGoToShop: {},
                isReceiving: false
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
