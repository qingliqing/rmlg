# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an iOS SwiftUI app called "renminglegou" (人名乐购) with integrated advertising and task management features. The app uses CocoaPods for dependency management and focuses heavily on ad mediation through various SDKs.

## Development Commands

### Build and Dependencies
- `pod install` - Install CocoaPods dependencies
- Build the project through Xcode using the workspace: `renminglegou.xcworkspace`
- Target deployment: iOS 13.0+

### Testing
- Run unit tests: Use Xcode's test navigator or `⌘+U`
- UI tests are available in `renminglegouUITests/`

## Architecture

### Core Structure
- **SwiftUI App**: Main entry point in `renminglegouApp.swift` with NavigationStack routing
- **Feature-Based Organization**: Code organized by features in `/Features` directory
- **Ad-Centric Design**: Heavy integration with multiple ad SDKs through `AdsManager/`

### Key Directories
- `renminglegou/Features/` - Feature modules (Chat, Splash, TaskCenter)
- `renminglegou/AdsManager/` - Ad management (Banner, Reward, Splash ads)
- `renminglegou/Network/` - Networking layer with Alamofire
- `renminglegou/WebView/` - WebView integration with H5 message handling
- `renminglegou/Utils/` - Shared utilities and helpers
- `renminglegou/Navigation/` - App routing and navigation

### Key Components
- **Router**: Central navigation using `NavigationStack` and `AppRoute` enum
- **SDKManager**: Manages initialization of multiple SDKs (ads, analytics)
- **AdSlotManager**: Centralized ad slot configuration and management
- **Logger**: Custom logging system with categories
- **PureLoadingManager**: Global loading state management

### Ad Integration
The app integrates multiple Chinese ad networks:
- CSJ (穿山甲/Pangle)
- Baidu Mobile Ads
- Tencent GDT
- KuaiShou
- Sigmob
- Mintegral
- Google AdMob
- Unity Ads

### Navigation Routes
- `.splash` - Splash screen
- `.webView(url, title, showBackButton)` - Web view pages
- `.taskCenter` - Task management interface
- `.djxPlaylet(config)` - Video playlet feature

## Important Notes
- Uses bridging header for Objective-C integration: `renminglegou-Bridging-Header.h`
- Payment integration through UnionPay: `UPPaymentControlMini.xcframework`
- Heavy reliance on CocoaPods for ad SDK management
- All critical SDKs must initialize before app functionality is available