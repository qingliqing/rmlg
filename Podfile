platform :ios, '13.0'
# 声明使用csjm插件
plugin 'cocoapods-byte-csjm'
use_frameworks!
# 设置为自动更新adapter版本号
use_gm_adapter_update!

# 设置线上构建target不自动更新（按照自己需要进行调整，可选）
target 'renminglegou' do
  # 网络库
  pod 'Alamofire', '~> 5.8'
  pod 'Ads-CN-Beta', '7.1.0.1', :subspecs => ['CSJMediation']
  # 引入使用到的ADN SDK，开发者请按需引入
  
  # 设置线上打包tag,该tag不再执行adapter自动更新，此时以adapter自动更新的最后一次结果去加载各adapter的版本
#  gm_release_target!
  
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
