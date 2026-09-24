import SentrySwift

SentrySDK.start { options in
    options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    options.debug = true
}
print("macOS-CLI-Xcode running with SentrySPM (NoUIFramework)")
