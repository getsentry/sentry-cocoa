Pod::Spec.new do |s|
  s.name         = "SentrySwiftUI"
  s.version      = "0.1.0"
  s.summary      = "Sentry client for SwiftUI"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "11.10"
  s.tvos.deployment_target = "10.0"
  s.watchos.deployment_target = "6.0"
  s.module_name  = "SentrySwiftUI"
  s.requires_arc = true
  s.frameworks = 'Foundation', 'SwiftUI'
  s.swift_versions = "5.0"
  s.watchos.pod_target_xcconfig = {
      'OTHER_LDFLAGS' => '$(inherited) -framework WatchKit'
  }

  s.default_subspecs = ['Core']
  
  s.subspec 'Core' do |sp|
      sp.source_files = "Sources/SentrySwiftUI/**/*.{swift}","Sources/SentryInternal/**/*.{h}"
      sp.dependency 'Sentry', '7.31.0'
  end
end
