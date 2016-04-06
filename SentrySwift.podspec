Pod::Spec.new do |s|
  s.name         = "SentrySwift"
  s.version      = "0.1.0"
  s.summary      = "Swift client for Sentry"
  s.homepage     = "https://github.com/getsentry/raven-swift"
  s.license      = "mit"
  s.authors      = "Josh Holtz"
  s.source       = { :git => "https://github.com/getsentry/raven-swift-new", :tag => s.version.to_s }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"

  s.source_files = "Sources/**/*.{h,m,swift}"

  s.ios.dependency 'KSCrash', '~> 1.1'

end
