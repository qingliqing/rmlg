//
//  BannerAdViewModel.swift
//  TaskCenter
//
//  Created by Developer on 2025/8/29.
//

import Foundation
import UIKit
import Combine

@MainActor
final class BannerAdViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var shouldShowBanner = false
    
    // MARK: - Private Properties
    private let bannerAdManager: BannerAdManager
    private var bannerStatusCancellable: Set<AnyCancellable> = []
    
    // MARK: - Initialization
    init(slotId: String = "103585837") {
        self.bannerAdManager = BannerAdManager(
            slotId: slotId,
            refreshInterval: 30.0,
            defaultAdSize: CGSize(width: UIScreen.main.bounds.width - 40, height: 160)
        )
        
        setupBannerAdObservers()
    }
    
    // MARK: - Private Methods
    private func setupBannerAdObservers() {
        bannerAdManager.$isLoaded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoaded in
                self?.shouldShowBanner = isLoaded
            }
            .store(in: &bannerStatusCancellable)
    }
    
    // MARK: - Public Methods
    func initializeBannerAd(in viewController: UIViewController) {
        let containerSize = CGSize(width: UIScreen.main.bounds.width - 40, height: 160)
        bannerAdManager.initializeAd(in: viewController, containerSize: containerSize)
    }
    
    func getBannerAdView() -> UIView? {
        return bannerAdManager.getBannerView()
    }
    
    func refreshBannerAd() async {
        await bannerAdManager.refreshAd()
    }
    
    func cleanupBannerAd() {
        Task { @MainActor in
            bannerAdManager.cleanup()
            shouldShowBanner = false
        }
    }
    
    // MARK: - Deinitializer
    deinit {
        bannerStatusCancellable.removeAll()
        
        // 不能在deinit中使用Task捕获self，直接使用DispatchQueue
        let manager = bannerAdManager
        DispatchQueue.main.async {
            manager.resetState()
        }
    }
}
