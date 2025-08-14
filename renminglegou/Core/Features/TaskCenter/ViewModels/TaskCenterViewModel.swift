//
//  TaskCenterViewModel.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation
import Combine

class TaskCenterViewModel: ObservableObject {
    @Published var tasks: [TaskModel] = []
    @Published var isLoading = false
    
    func loadTasks() {
        isLoading = true
        
        // 模拟网络请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.tasks = self.generateMockTasks()
            self.isLoading = false
        }
    }
    
    func completeTask(_ task: TaskModel) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted = true
            // 这里可以调用 API 上报任务完成
            print("任务完成: \(task.title)")
        }
    }
    
    private func generateMockTasks() -> [TaskModel] {
        return [
            TaskModel(title: "每日签到", description: "完成每日签到任务", reward: 10),
            TaskModel(title: "观看短视频", description: "观看3个短视频", reward: 20),
            TaskModel(title: "分享给好友", description: "分享应用给好友", reward: 50),
            TaskModel(title: "完成运动", description: "完成一次AI运动", reward: 30),
            TaskModel(title: "邀请新用户", description: "邀请新用户注册", reward: 100)
        ]
    }
}
