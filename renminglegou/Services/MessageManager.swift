//
//  MessageManager.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation

class MessageManager {
    static func getUnreadCount() -> Int {
        return UserDefaults.standard.integer(forKey: "unread_message_count")
    }
    
    static func setUnreadCount(_ count: Int) {
        UserDefaults.standard.set(count, forKey: "unread_message_count")
    }
    
    static func incrementUnreadCount() {
        let currentCount = getUnreadCount()
        setUnreadCount(currentCount + 1)
    }
    
    static func clearUnreadCount() {
        setUnreadCount(0)
    }
}
