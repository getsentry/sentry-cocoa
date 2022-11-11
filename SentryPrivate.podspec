Pod::Spec.new do |s|
  s.name         = "SentryPrivate"
  s.version      = "0.1.0"
  s.summary      = "Sentry Private Library."
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => "alpha-" + s.version.to_s }
  s.social_media_url = 'https://getsentry.com/'

  s.description      = <<-DESC
   Not for public use.
   Common APIs for internal Sentry usage.
                        DESC
  
  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  s.module_name  = "SentryPrivate"
  s.frameworks = 'Foundation'

  s.swift_versions = "5.5"
  s.watchos.framework = 'WatchKit'
  
  s.source_files = "Sources/Swift/**/*.{swift}"
end
