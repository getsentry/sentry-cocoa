Pod::Spec.new do |s|
  s.name         = "SentryPrivate"
  s.version      = "8.22.0-alpha.0"
  s.summary      = "Sentry Private Library."
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }
  s.social_media_url = 'https://getsentry.com/'
  s.deprecated = true

  s.description      = <<-DESC
   Not for public use.
   Common APIs for internal Sentry usage.
                        DESC
  
  s.ios.deployment_target = "11.0"
  s.osx.deployment_target = "10.13"
  s.tvos.deployment_target = "11.0"
  s.watchos.deployment_target = "4.0"
  s.visionos.deployment_target = "1.0"
  s.module_name  = "SentryPrivate"
  s.frameworks = 'Foundation'

  s.swift_versions = "5.5"
  s.watchos.framework = 'WatchKit'
  
  s.source_files = "Sources/Swift/**/*.{swift}"
end
