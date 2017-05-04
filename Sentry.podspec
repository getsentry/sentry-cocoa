Pod::Spec.new do |s|
  s.name         = "Sentry"
  s.version      = "3.0.0"
  s.summary      = "Sentry client for cocoa"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git", :tag => s.version.to_s }

  s.ios.deployment_target = "8.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"

  s.source_files = "Sources/Sentry/**/*.{h,m,swift}"

  s.subspec 'KSCrash' do |ks|
    ks.dependency 'KSCrash', '~> 1.15.8'
  end
end
