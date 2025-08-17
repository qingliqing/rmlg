//
//  ActivityModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/17.
//

import Foundation

struct ActivityModel: Codable, Identifiable {
    let id = UUID()
    let acId: String
    let name: String
    let acUrl: String
    let urlType: Int
    let imageUrl: String
    
    enum CodingKeys: String, CodingKey {
        case acId, name, acUrl, urlType, imageUrl
    }
    
    init(acId: String = "",
         name: String = "",
         acUrl: String = "",
         urlType: Int = 1,
         imageUrl: String = "") {
        self.acId = acId
        self.name = name
        self.acUrl = acUrl
        self.urlType = urlType
        self.imageUrl = imageUrl
    }
}
