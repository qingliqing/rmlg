//
//  TaskModel.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation

struct TaskModel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let reward: Int
    var isCompleted: Bool = false
}
