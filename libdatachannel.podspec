Pod::Spec.new do |s|
  s.name         = "libdatachannel"
  s.version      = "0.24.1"
  s.summary      = "WebRTC Data Channels for iOS and macOS"
  s.homepage     = "https://github.com/alexshawnee/libdatachannel"
  s.license      = { :type => "MPL-2.0" }
  s.author       = "Paul-Louis Ageneau"
  s.source       = { :http => "https://github.com/alexshawnee/libdatachannel/releases/download/v#{s.version}-darwin/libdatachannel.xcframework.zip" }
  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "11.0"
  s.vendored_frameworks = "libdatachannel.xcframework"
end
