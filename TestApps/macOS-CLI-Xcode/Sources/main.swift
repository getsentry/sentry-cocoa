import Foundation
import SentrySwift

if CommandLine.arguments.contains("--validate-in-app-frames") {
    guard let executablePath = Bundle.main.executablePath else {
        print("Unable to locate the CLI executable")
        exit(EXIT_FAILURE)
    }
    let resolvedExecutablePath = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().path
    var capturedMainFrames = false
    SentrySDK.start { options in
        // Local-only destination and a dropping callback prevent external event uploads.
        options.dsn = "http://public@127.0.0.1:1/1"
        options.enableCrashHandler = false
        options.enableAutoSessionTracking = false
        options.attachStacktrace = true
        options.beforeSend = { event in
            let frames = event.threads?.flatMap { $0.stacktrace?.frames ?? [] } ?? []
            // The test oracle handles both reporters' path spellings. Production frame
            // mapping uses cached image identity rather than filesystem resolution.
            let mainImageNames = Set(frames.compactMap(\.package)).filter {
                URL(fileURLWithPath: $0).resolvingSymlinksInPath().path == resolvedExecutablePath
            }
            let mainFrames = frames.filter { mainImageNames.contains($0.package ?? "") }
            if mainFrames.isEmpty {
                print("Expected executable: \(executablePath)")
                print("Frame images: \(Set(frames.compactMap(\.package)).sorted())")
            }
#if SDK_V10
            capturedMainFrames = !mainFrames.isEmpty && mainFrames.allSatisfy { $0.inApp == true }
#else
            capturedMainFrames = !mainFrames.isEmpty && mainFrames.allSatisfy { $0.inApp == false }
#endif
            return nil
        }
        precondition(options.inAppIncludes.isEmpty, "CLI validation requires empty in-app includes")
    }
    SentrySDK.capture(message: "CLI in-app frame validation")
    SentrySDK.close()
    guard capturedMainFrames else {
        print("CLI main executable frame classification failed")
        exit(EXIT_FAILURE)
    }
    print("CLI main executable frame classification validated")
} else {
    SentrySDK.start { options in
        options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
        options.debug = true
    }
    print("macOS-CLI-Xcode running with SentrySPM (NoUIFramework)")
}
