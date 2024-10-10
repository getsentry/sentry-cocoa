import Sentry
import SwiftUI

struct Options {
    static var dsnHash: String?
    static var cacheDirPath: String?
}

@main
struct SwiftUITestSampleApp: App {
    init() {
        SentrySDK.start { options in
            options.debug = true
            options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
            Options.dsnHash = options.parsedDsn?.getHash()
            Options.cacheDirPath = options.cacheDirectoryPath
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Text("Welcome!")
            Button("Crash") {
                SentrySDK.crash()
            }
            Button("Close SDK") {
                SentrySDK.close()
            }
            Button("Write Corrupted Envelope") {
                guard let dsnHash = Options.dsnHash else {
                    fatalError("dsnHash can not be nil!")
                }

                guard let cachePath = Options.cacheDirPath else {
                    fatalError("cacheDirPath can not be nil!")
                }

                let envelopePath = "\(cachePath)/io.sentry/\(dsnHash)/envelopes/corrupted-envelope.json"
                let corruptedEnvelopeData = """
                       {"event_id":"1990b5bc31904b7395fd07feb72daf1c","sdk":{"name":"sentry.cocoa","version":"8.33.0"}}
                       {"type":"test","length":50}
                       """.data(using: .utf8)!

                do {
                    try corruptedEnvelopeData.write(to: URL(fileURLWithPath: envelopePath))
                    print("Corrupted envelope saved to: " + envelopePath)
                } catch {
                    fatalError("Error while writing corrupted envelope to: " + envelopePath)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
