//
//  AlertViews.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import SwiftUI

struct RewardPopupView: View {
    @Environment(\.dismiss) private var dismiss
    let task: AdTask?        // 可选 AdTask
    let onStartAction: () -> Void
    
    // 计算背景图片的实际高度
    private var imageHeight: CGFloat {
//        let screenWidth = UIScreen.main.bounds.width - 40
//        let imageAspectRatio = image.size.height / image.size.width
//        return screenWidth * imageAspectRatio
        return UIScreen.main.bounds.size.height - 328
    }
    
    var body: some View {
        ZStack {
            // 背景图片
            Image("swipe_task_alert_bg")
                .resizable()
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.size.height - 328)
                .ignoresSafeArea(edges: .bottom) // 忽略底部安全区
            
            // 文本内容覆盖层
            VStack(spacing: 12) {
                // MARK: - Title (level1)
                if let title = task?.taskDescription?.level1?.displayText, !title.isEmpty {
                    Text(title)
                        .font(.system(size: task?.taskDescription?.level1?.displayFontSize ?? 32, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, imageHeight * 0.3)
                }
                
                // MARK: - Level2 ~ Level4
                VStack(spacing: 4) {
                    if let level2 = task?.taskDescription?.level2?.displayText, !level2.isEmpty {
                        Text(level2)
                            .font(.system(size: task?.taskDescription?.level2?.displayFontSize ?? 16))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                    }
                    if let level3 = task?.taskDescription?.level3?.displayText, !level3.isEmpty {
                        Text(level3)
                            .font(.system(size: task?.taskDescription?.level3?.displayFontSize ?? 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                    }
                    if let level4 = task?.taskDescription?.level4?.displayText, !level4.isEmpty {
                        Text(level4)
                            .font(.system(size: task?.taskDescription?.level4?.displayFontSize ?? 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
                
                // MARK: - Button
                Button(action: {
                    onStartAction()
                    dismiss()
                }) {
                    Image("swipe_alert_start_btn")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 50)
                .padding(.bottom, 44)
            }
        }
        .ignoresSafeArea()
        .frame(height: imageHeight) // 设置为图片的实际高度
        .presentationDetents([.height(imageHeight)]) // 使用计算出的高度
        .presentationDragIndicator(.hidden)
        .padding(.horizontal, 20)
    }
}
