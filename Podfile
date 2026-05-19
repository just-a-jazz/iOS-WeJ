platform :ios, '15.6'

target 'WeJ' do
  # Comment the next line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!
  inhibit_all_warnings!

  # Pods for WeJ
  pod 'RKNotificationHub'
  pod 'SwiftyJSON'
  pod 'NVActivityIndicatorView'
  pod 'Siren'
  pod 'M13Checkbox' 
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.6'
    end
  end
end
