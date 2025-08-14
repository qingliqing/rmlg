platform :ios, '13.0'
use_frameworks!

target 'renminglegou' do
  # 网络库
  pod 'Alamofire', '~> 5.8'
  
  # 如果需要其他库，可以逐个取消注释测试
  # pod 'SDWebImageSwiftUI', '~> 2.2'
  # pod 'SnapKit', '~> 5.6'
  # pod 'SwiftyJSON', '~> 5.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      # 添加这行来解决权限问题
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
end
