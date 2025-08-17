//
//  TaskCenterActivityCell.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct TaskCenterActivityCell: View {
    let activity: ActivityModel
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Activity icon
                activityIcon
                
                // Activity info
                activityInfo
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(ActivityCellButtonStyle())
    }
    
    // MARK: - Activity Icon
    private var activityIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.2),
                            Color.purple.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
            
            Image(systemName: activityIconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.blue)
        }
    }
    
    // MARK: - Activity Info
    private var activityInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(activity.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(activitySubtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    // MARK: - Computed Properties
    private var activityIconName: String {
        switch activity.urlType {
        case 1:
            return "star.circle.fill"
        case 2:
            return "link.circle.fill"
        default:
            return "app.gift.fill"
        }
    }
    
    private var activitySubtitle: String {
        switch activity.urlType {
        case 1:
            return "内部活动 · 点击参与"
        case 2:
            return "外部链接 · 跳转页面"
        default:
            return "特殊活动 · 立即查看"
        }
    }
}

// MARK: - Custom Button Style
struct ActivityCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview
struct TaskCenterActivityCell_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            TaskCenterActivityCell(
                activity: ActivityModel(
                    acId: "act_001",
                    name: "限时活动1",
                    acUrl: "/activity1",
                    urlType: 1,
                    imageUrl: ""
                ),
                onTap: {}
            )
            
            TaskCenterActivityCell(
                activity: ActivityModel(
                    acId: "act_002",
                    name: "外部合作活动",
                    acUrl: "https://external.com/activity2",
                    urlType: 2,
                    imageUrl: ""
                ),
                onTap: {}
            )
            
            TaskCenterActivityCell(
                activity: ActivityModel(
                    acId: "act_003",
                    name: "特殊推广活动",
                    acUrl: "/special_activity",
                    urlType: 3,
                    imageUrl: ""
                ),
                onTap: {}
            )
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}
