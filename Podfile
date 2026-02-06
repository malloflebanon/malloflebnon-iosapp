# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

target 'MallOfLebanon-iOS' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for MallOfLebanon-iOS

  # Socket.IO for real-time auction communication
  pod 'Socket.IO-Client-Swift', '~> 16.0'

  # Additional pods for enhanced functionality
  pod 'SDWebImage', '~> 5.0' # For enhanced image loading and caching

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end