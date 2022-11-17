Pod::Spec.new do |s|
  s.name         = "Sentry"
  s.version      = "7.31.1"
  s.summary      = "Sentry client for cocoa"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  s.module_name  = "Sentry"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  s.libraries = 'z', 'c++'
  s.swift_versions = "5.5"
  s.pod_target_xcconfig = {
      'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES',
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
      'CLANG_CXX_LIBRARY' => 'libc++'
  }
  s.watchos.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -framework WatchKit'
  }

  s.default_subspecs = ['Core']
  s.dependency "SentryPrivate", "7.31.0"

  s.subspec 'Core' do |sp|
      sp.source_files = "Sources/Sentry/**/*.{h,hpp,m,mm,c,cpp}",
        "Sources/SentryCrash/**/*.{h,hpp,m,mm,c,cpp}", "Sources/Swift/Sentry.swift"
      sp.public_header_files =
        "Sources/Sentry/Public/*.h"
  end
  
  s.subspec 'HybridSDK' do |sp|
      sp.source_files = "Sources/Sentry/**/*.{h,hpp,m,mm,c,cpp}",
        "Sources/SentryCrash/**/*.{h,hpp,m,mm,c,cpp}", "Sources/Swift/Sentry.swift"
        
      sp.public_header_files =
        "Sources/Sentry/Public/*.h", "Sources/Sentry/include/PrivateSentrySDKOnly.h"
  end
end
