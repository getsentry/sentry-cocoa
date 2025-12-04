Pod::Spec.new do |s|
  s.name         = "SentrySwiftUI"
  s.version      = "9.0.0"
  s.summary      = "Sentry client for SwiftUI"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "15.0"
  s.osx.deployment_target = "12"
  s.tvos.deployment_target = "15.0"
  s.watchos.deployment_target = "8.0"
  s.module_name  = "SentrySwiftUI"
  s.requires_arc = true
  s.frameworks = 'Foundation', 'SwiftUI'
  s.swift_versions = "5.5"
  s.watchos.framework = 'WatchKit'

  s.source_files = "Sources/SentrySwiftUI/**/*.{swift,h,m}"
  s.dependency 'Sentry/HybridSDK', "9.0.0"
end
