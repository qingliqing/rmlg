//
//  DataUtil.swift
//  renminglegou
//
//  Created by abc on 2025/8/12.
//

import Foundation

class DataUtil {
    static func stringOf(_ value: Any?, defaultValue: String = "") -> String {
        if let stringValue = value as? String {
            return stringValue.isEmpty ? defaultValue : stringValue
        }
        return defaultValue
    }
    
    static func intOf(_ value: Any?, defaultValue: Int = 0) -> Int {
        if let intValue = value as? Int {
            return intValue
        }
        if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue
        }
        return defaultValue
    }
    
    static func boolOf(_ value: Any?, defaultValue: Bool = false) -> Bool {
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let stringValue = value as? String {
            return stringValue.lowercased() == "true" || stringValue == "1"
        }
        return defaultValue
    }
}
