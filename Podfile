source 'https://github.com/CocoaPods/Specs.git'
source 'https://github.com/volcengine/volcengine-specs.git'

platform :ios, '13.0'
# 声明使用csjm插件
#plugin 'cocoapods-byte-csjm'
use_frameworks!
# 设置为自动更新adapter版本号
#use_gm_adapter_update!

# 设置线上构建target不自动更新（按照自己需要进行调整，可选）
target 'renminglegou' do
  # 网络库
  pod 'Alamofire', '~> 5.8'
  pod 'Ads-CN-Beta', '7.1.0.7', :subspecs => ['CSJMediation-Only','BUAdTestMeasurement']
#  pod 'BUAdTestMeasurement-beta', '7.1.0.1', :configuration => 'Debug'


  # 引入使用到的ADN SDK，开发者请按需引入
  pod 'TTSDKFramework', '1.42.3.4-premium', :subspecs => [ 'Player-SR' ]
  pod 'PangrowthX', '2.8.0.0', :subspecs => [ 'shortplay-beta' ]
  
  pod 'GMBaiduAdapter-Beta', '5.394.0'
  pod 'GMGdtAdapter-Beta', '4.15.41.2'
  pod 'GMKsAdapter-Beta', '4.6.30.1.2'
  pod 'GMMintegralAdapter-Beta', '7.7.7.1'
  pod 'GMSigmobAdapter-Beta', '4.20.0.0'
  pod 'GMUnityAdapter-Beta', '4.3.0.1'
  pod 'GMAdmobAdapter-Beta', '10.0.0.1'
  
  # 引入使用到的ADN SDK，开发者请按需引入
  pod 'GDTMobSDK', '4.15.41'
  pod 'BaiduMobAdSDK', '5.394'
  pod 'KSAdSDK', '4.6.30.1'
  pod 'SigmobAd-iOS', '4.20.0'
  pod 'MintegralAdSDK', '7.7.7'
  pod 'Google-Mobile-Ads-SDK', '10.0.0'
  pod 'UnityAds', '4.3.0'
  
  # 设置线上打包tag,该tag不再执行adapter自动更新，此时以adapter自动更新的最后一次结果去加载各adapter的版本
#  gm_release_target!
  
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
