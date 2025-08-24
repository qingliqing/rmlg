//
//  UserModel.swift
//  renminglegou
//
//  Created by abc on 2025/8/11.
//

import Foundation
import Combine

class UserModel: ObservableObject {
    static let shared = UserModel()
    
    @Published var token: String = ""
    @Published var userId: String = ""
    @Published var isLoggedIn: Bool = false
    
    private init() {
        // 从 UserDefaults 恢复登录状态
        if let savedToken = UserDefaults.standard.string(forKey: "user_token"), !savedToken.isEmpty {
            self.token = savedToken
            self.isLoggedIn = true
        }
    }
    
    func updateToken(_ newToken: String) {
        token = newToken
        isLoggedIn = !newToken.isEmpty
        UserDefaults.standard.set(newToken, forKey: "user_token")
    }
    
    func logout() {
        token = ""
        userId = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "user_token")
    }
}
