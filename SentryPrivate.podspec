Pod::Spec.new do |s|
  s.name         = "SentryPrivate"
  s.version      = "7.30.0"
  s.summary      = "Sentry Private Library. Do not target this directly"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  s.module_name  = "SentryPrivate"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  s.libraries = 'c++'
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
  
  s.subspec 'Core' do |sp|
      sp.source_files = "Sources/Swift/**/*.{swift}"
  end
  
end
