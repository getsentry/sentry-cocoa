Pod::Spec.new do |s|
  s.name         = "Sentry"
  s.version      = "7.23.0"
  s.summary      = "Sentry client for cocoa"
  s.homepage     = "https://github.com/getsentry/sentry-cocoa"
  s.license      = "mit"
  s.authors      = "Sentry"
  s.source       = { :git => "https://github.com/getsentry/sentry-cocoa.git",
                     :tag => s.version.to_s }

  s.ios.deployment_target = "9.0"
  s.osx.deployment_target = "10.10"
  s.tvos.deployment_target = "9.0"
  s.watchos.deployment_target = "2.0"
  s.module_name  = "Sentry"
  s.requires_arc = true
  s.frameworks = 'Foundation'
  s.libraries = 'z', 'c++'
  s.pod_target_xcconfig = {
      'GCC_ENABLE_CPP_EXCEPTIONS' => 'YES',
      'CLANG_CXX_LANGUAGE_STANDARD' => 'c++14',
      'CLANG_CXX_LIBRARY' => 'libc++',
      'HEADER_SEARCH_PATHS' => '${PODS_TARGET_SRCROOT}/Sources/SwiftDemangling/include'
 }

  s.default_subspecs = ['Core']

  s.subspec 'Core' do |sp|
      sp.source_files = "Sources/Sentry/**/*.{h,hpp,m,mm,c,cpp}",
        "Sources/SentryCrash/**/*.{h,hpp,m,mm,c,cpp}"
      sp.ios.source_files = "Sources/SwiftDemangling/**/*.{h,hpp,m,mm,c,cpp,def}"
      sp.tvos.source_files = "Sources/SwiftDemangling/**/*.{h,hpp,m,mm,c,cpp,def}"
      
      sp.public_header_files =
        "Sources/Sentry/Public/*.h"
      
      sp.compiler_flags = '-Wshorten-64-to-32', '-Wunused-parameter'
  end
end
