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

  # Manually download the Sentry.xcframework and unzip it because we also need the headers for the HybridSDK subspec
  s.prepare_command = <<-CMD
    curl -L "https://github.com/getsentry/sentry-cocoa/releases/download/9.0.0/Sentry.xcframework.zip" -o Sentry.xcframework.zip
    
    export SENTRY_CHECKSUM="e54ed4597496468737e917e7826d90a40ee98f4985554651e32ddfcd82050f27"
    shasum -a 256 Sentry.xcframework.zip | awk '{print $1}' | grep "$SENTRY_CHECKSUM"
    if [ $? -ne 0 ]; then
      echo "Error: Sentry.xcframework.zip checksum does not match"
      exit 1
    fi

    unzip -o Sentry.xcframework.zip
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
