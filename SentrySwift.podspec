Pod::Spec.new do |s|
  s.name         = "SentrySwift"
  s.version      = "1.4.2"
  s.summary      = "Swift client for Sentry"
  s.homepage     = "https://github.com/getsentry/sentry-swift"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-swift.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source_files = "Sources/*.{h,m,swift}"
  s.ios.source_files = "Sources/ios/*.{h,m,swift}"

  s.ios.resource_bundles = {
    'storyboards' => ['Sources/ios/*.{storyboard}'],
    'assets' => ['Sources/ios/*.{xcassets}']
  }
  
  s.dependency 'KSCrash', '~> 1.13.6'
end
