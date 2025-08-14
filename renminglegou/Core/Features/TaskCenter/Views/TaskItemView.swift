//
//  TaskItemView.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import SwiftUI

struct TaskItemView: View {
    let task: TaskModel
    let onComplete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(task.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    
                    Text("奖励: \(task.reward)金币")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            
            Button(action: onComplete) {
                Text(task.isCompleted ? "已完成" : "完成")
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(task.isCompleted)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }
}
