//
//  SwipeVideoViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/29.
//

import Foundation
import Combine

@MainActor
final class SwipeTaskViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isWatchingVideo = false
    @Published var videoProgress: Double = 0.0
    
    // MARK: - Private Properties
    private let loadingManager = PureLoadingManager.shared
    private var videoTimer: Timer?
    private let videoDuration: TimeInterval = 15.0
    
    // MARK: - Callbacks
    var onVideoCompleted: (() async -> Void)?
    
    // MARK: - Public Methods
    
    /// 开始刷视频
    func startSwipeVideo() {
        guard !isWatchingVideo else { return }
        
        loadingManager.showLoading(style: .dots)
        loadingManager.hideLoading()
        
        startVideoProgress()
    }
    
    /// 停止刷视频
    func stopSwipeVideo() {
        isWatchingVideo = false
        videoProgress = 0.0
        videoTimer?.invalidate()
        videoTimer = nil
    }
    
    // MARK: - Private Methods
    
    private func startVideoProgress() {
        isWatchingVideo = true
        videoProgress = 0.0
        
        videoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateVideoProgress()
            }
        }
    }
    
    private func updateVideoProgress() {
        videoProgress += 0.1 / videoDuration
        
        if videoProgress >= 1.0 {
            videoProgress = 1.0
            stopSwipeVideo()
            
            Task {
                await onVideoCompleted?()
            }
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        videoTimer?.invalidate()
    }
}
