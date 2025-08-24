//
//  ChatViewModel.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation
import Combine

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    
    func loadMessages() {
        isLoading = true
        
        // 模拟加载历史消息
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.messages = [
                ChatMessage(content: "欢迎使用人民乐购！", isFromUser: false),
                ChatMessage(content: "有什么可以帮助您的吗？", isFromUser: false)
            ]
            self.isLoading = false
        }
    }
    
    func sendMessage(_ content: String) {
        // 添加用户消息
        let userMessage = ChatMessage(content: content, isFromUser: true)
        messages.append(userMessage)
        
        // 模拟机器人回复
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let botReply = self.generateBotReply(for: content)
            self.messages.append(botReply)
        }
    }
    
    private func generateBotReply(for userMessage: String) -> ChatMessage {
        let replies = [
            "感谢您的消息！",
            "我已经收到您的问题，正在为您处理。",
            "有什么其他可以帮助您的吗？",
            "您的反馈对我们很重要！"
        ]
        
        let randomReply = replies.randomElement() ?? "收到！"
        return ChatMessage(content: randomReply, isFromUser: false)
    }
}
