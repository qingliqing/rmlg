//
//  TaskCenterHeaderView.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct TaskCenterHeaderView: View {
    
    var body: some View {
        VStack(spacing: 0) {
            // Main header content
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.8),
                        Color.purple.opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Content overlay
                VStack(spacing: 12) {
                    // Title
                    Text("签到中心")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // Subtitle
                    Text("完成任务获得丰厚奖励")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    // Decorative elements
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                                .scaleEffect(index == 1 ? 1.2 : 1.0)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 32)
            }
            .frame(height: 140)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Preview
struct TaskCenterHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TaskCenterHeaderView()
            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}
