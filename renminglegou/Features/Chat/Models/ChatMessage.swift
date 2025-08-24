//
//  ChatMessage.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let content: String
    let isFromUser: Bool
    let timestamp: Date
    let messageType: ChatMessageType
    let status: MessageStatus
    
    // 可选的扩展属性
    let avatarURL: String?
    let userName: String?
    let replyToMessageId: UUID?
    
    init(content: String,
         isFromUser: Bool,
         messageType: ChatMessageType = .text,
         status: MessageStatus = .sent,
         avatarURL: String? = nil,
         userName: String? = nil,
         replyToMessageId: UUID? = nil) {
        self.content = content
        self.isFromUser = isFromUser
        self.messageType = messageType
        self.status = status
        self.timestamp = Date()
        self.avatarURL = avatarURL
        self.userName = userName
        self.replyToMessageId = replyToMessageId
    }
}

// 消息类型枚举
enum ChatMessageType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case voice = "voice"
    case video = "video"
    case link = "link"
    case file = "file"
    case system = "system"  // 系统消息
}

// 消息状态枚举
enum MessageStatus: String, Codable {
    case sending = "sending"    // 发送中
    case sent = "sent"         // 已发送
    case delivered = "delivered" // 已送达
    case read = "read"         // 已读
    case failed = "failed"     // 发送失败
}
