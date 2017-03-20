Pod::Spec.new do |s|
  s.name         = "Sentry"
  s.version      = "2.1.9"
  s.summary      = "Swift client for Sentry"
  s.homepage     = "https://github.com/getsentry/sentry-swift"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-swift.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  
  s.default_subspecs = 'KSCrash'
  
  s.subspec 'Core' do |cs|
    cs.source_files = ["Sources/Sentry/*.{h,m,swift}", "Sources/Sentry/Core/*.{h,m,swift}"]
    
    cs.ios.source_files = "Sources/Sentry/ios/*.{h,m,swift}"
    cs.ios.resource_bundles = {
      'storyboards' => ['Sources/Sentry/ios/*.{storyboard}'],
      'assets' => ['Sources/ios/*.{xcassets}']
    }
  end

  s.subspec 'KSCrash' do |ks|
    ks.source_files = ["Sources/Sentry/*.{h,m,swift}", "Sources/Sentry/KSCrash/*.{h,m,swift}"]
    ks.dependency 'KSCrash', '~> 1.15.3'
    
    ks.ios.source_files = "Sources/Sentry/ios/*.{h,m,swift}"
    ks.ios.resource_bundles = {
      'storyboards' => ['Sources/Sentry/ios/*.{storyboard}'],
      'assets' => ['Sources/ios/*.{xcassets}']
    }
  end
end
