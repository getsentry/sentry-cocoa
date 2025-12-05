Pod::Spec.new do |s|
  s.name         = "Sentry"
  s.version      = "9.0.0"
  s.summary      = "Sentry client for cocoa"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "15.0"
  s.osx.deployment_target = "12"
  s.tvos.deployment_target = "15.0"
  s.watchos.deployment_target = "8.0"
  s.visionos.deployment_target = "1.0"
  s.module_name  = "Sentry"
  s.swift_versions = "5.5"
  s.pod_target_xcconfig = {
      'CLANG_CXX_LIBRARY' => 'libc++'
  }
  s.preserve_paths = 'Sentry.xcframework'
  s.static_framework = true

  # Manually download the Sentry.xcframework and unzip it because we also need the headers for the HybridSDK subspec
  s.prepare_command = <<-CMD
    curl -L "https://github.com/getsentry/sentry-cocoa/releases/download/9.0.0/Sentry-Dynamic.xcframework.zip" -o Sentry-Dynamic.xcframework.zip
    
    export SENTRY_CHECKSUM="9e7571fc539a6e6850e3d792a0afc9abe63c75261774da6b99d66f426e0c52f7"
    shasum -a 256 Sentry-Dynamic.xcframework.zip | awk '{print $1}' | grep "$SENTRY_CHECKSUM"
    if [ $? -ne 0 ]; then
      echo "Error: Sentry-Dynamic.xcframework.zip checksum does not match"
      exit 1
    fi

    unzip -o Sentry-Dynamic.xcframework.zip
  CMD

  s.default_subspecs = ['Core']

  s.subspec 'Core' do |sp|
    sp.vendored_frameworks = 'Sentry.xcframework'
  end
  
  s.subspec 'HybridSDK' do |sp|
      sp.dependency 'Sentry/Core'
      sp.source_files = "Sources/Sentry/Public/*.h", "Sources/Sentry/include/HybridPublic/*.h"
      sp.public_header_files = "Sources/Sentry/Public/*.h", "Sources/Sentry/include/HybridPublic/*.h"
  end
end
