Pod::Spec.new do |s|
  s.name         = "HybridPod"
  s.version      = "1.0.0"
  s.summary      = "Test for HybridSDK pod"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "11.0"
  s.module_name  = "SentryHybridTest"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  s.swift_versions = "5.5"
  s.dependency "Sentry/HybridSDK", "8.25.0"
  s.source_files = "HybridTest.swift"
end
