//
//  TaskCenterView.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import SwiftUI

struct TaskCenterView: View {
    @StateObject private var viewModel = TaskCenterViewModel()
    
    var body: some View {
        VStack {
            Text("任务中心")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.tasks) { task in
                        TaskItemView(task: task) {
                            viewModel.completeTask(task)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationTitle("任务中心")
        .navigationBarHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadTasks()
        }
    }
}
