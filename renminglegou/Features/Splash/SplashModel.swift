//
//  SplashModel.swift
//  renminglegou
//
//  Created by Developer on 9/1/25.
//

import Foundation

// MARK: - 启动页数据模型
struct SplashData: Codable {
    let id: Int?
    let templateId: Int?
    let createTime: String?
    let remark: String?
    let params: [String: String]?
    let layout: SplashLayout?
    
    // 计算属性，从layout中提取需要的值
    var imageURL: String? {
        return layout?.imgList?.first?.url
    }
    
    var displayDuration: TimeInterval {
        return TimeInterval(layout?.timing ?? 3)
    }
    
    var skipEnabled: Bool {
        return layout?.open ?? true
    }
    
    static let `default` = SplashData(
        id: nil,
        templateId: nil,
        createTime: nil,
        remark: nil,
        params: nil,
        layout: SplashLayout(
            open: true,
            openType: 1,
            timing: 3,
            showCount: "3",
            showType: 1,
            imgList: nil
        )
    )
}

struct SplashLayout: Codable {
    let open: Bool?
    let openType: Int?
    let timing: Int?
    let showCount: String?
    let showType: Int?
    let imgList: [SplashImage]?
}

struct SplashImage: Codable {
    let url: String?
    let link: SplashLink?
}

struct SplashLink: Codable {
    let linkName: String?
    let linkUrl: String?
}
