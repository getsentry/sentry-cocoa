Pod::Spec.new do |s|
  s.name         = "SentrySwift"
  s.version      = "0.5.0"
  s.summary      = "Swift client for Sentry"
  s.homepage     = "https://github.com/getsentry/sentry-swift"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-swift.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source_files = "Sources/**/*.{h,m,swift}"
  s.source_files = "Sources/**/*.{h,m,swift}"
  s.resource_bundles = {
    'storyboards' => ['Sources/**/*.{storyboard}']
  }
  
  s.dependency 'KSCrash', '~> 1.10.1'
end
