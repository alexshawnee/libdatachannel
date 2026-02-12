Pod::Spec.new do |s|
  s.name         = "libdatachannel"
  s.version      = "0.24.1"
  s.summary      = "WebRTC Data Channels for iOS"
  s.homepage     = "https://github.com/alexshawnee/libdatachannel"
  s.license      = { :type => "MPL-2.0" }
  s.author       = "Paul-Louis Ageneau"
  s.source       = { :http => "https://github.com/alexshawnee/libdatachannel/releases/download/v0.24.1-ios/libdatachannel.xcframework.zip" }
  s.ios.deployment_target = "13.0"
  s.vendored_frameworks = "libdatachannel.xcframework"
end
