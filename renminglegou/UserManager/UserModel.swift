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
        if let savedToken = UserDefaults.standard.string(forKey: UserDefaultsKeys.userToken), !savedToken.isEmpty {
            self.token = savedToken
            self.isLoggedIn = true
        }
        
        if let savedUserId = UserDefaults.standard.string(forKey: UserDefaultsKeys.userId),
            !savedUserId.isEmpty {
            self.userId = savedUserId
        }
        
    }
    
    func updateToken(_ newToken: String) {
        token = newToken
        isLoggedIn = !newToken.isEmpty
        UserDefaults.standard.set(newToken, forKey: UserDefaultsKeys.userToken)
    }
    
    func updateUserid(_ newUserId: String) {
        userId = newUserId
        UserDefaults.standard.set(newUserId, forKey: UserDefaultsKeys.userId)
    }
    
    func logout() {
        token = ""
        userId = ""
        isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "user_token")
    }
}
