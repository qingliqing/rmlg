//
//  TaskCenterInfoModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation

struct TaskCenterInfoModel: Codable, Identifiable {
    let id = UUID()
    let taskId: String
    let userId: String
    let adSkipTime: Int
    let advViewNum: Int
    let isCompleted: Bool
    let title: String
    let description: String
    let reward: Int
    
    enum CodingKeys: String, CodingKey {
        case taskId, userId, adSkipTime, advViewNum, isCompleted, title, description, reward
    }
    
    init(taskId: String = "",
         userId: String = "",
         adSkipTime: Int = 0,
         advViewNum: Int = 0,
         isCompleted: Bool = false,
         title: String = "",
         description: String = "",
         reward: Int = 0) {
        self.taskId = taskId
        self.userId = userId
        self.adSkipTime = adSkipTime
        self.advViewNum = advViewNum
        self.isCompleted = isCompleted
        self.title = title
        self.description = description
        self.reward = reward
    }
}
