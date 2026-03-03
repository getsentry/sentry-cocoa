import SentrySwift

SentrySDK.start { options in
    options.dsn = ""
    options.debug = true
}
print("macOS-CLI-Xcode running with SentrySPM (NoUIFramework)")
