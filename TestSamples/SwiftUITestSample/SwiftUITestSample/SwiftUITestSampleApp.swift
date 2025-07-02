import Sentry
import SwiftUI

@main
struct SwiftUITestSampleApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var errorMessage: String?
    
    var body: some View {
        VStack {
            Text("Welcome!")
            Button("Crash") {
                SentrySDK.crash()
            }
            Button("Start SDK") {
                startSDK()
            }
            Button("Write Corrupted Envelope") {
                do {
                    errorMessage = nil // Clear any previous error
                    try writeCorruptedEnvelope()
                } catch let error as WriteCorruptedEnvelopeError {
                    errorMessage = error.message
                } catch {
                    errorMessage = "Unknown error: \(error)"
                }
            }

            if let errorMessage = errorMessage {
                Text("\(errorMessage)")
                    .accessibilityIdentifier("errorMessage")
            }
        }
    }
}

private var sentryOptions: Options = {
    let options = Options()
    options.dsn = "https://6cc9bae94def43cab8444a99e0031c28@o447951.ingest.sentry.io/5428557"
    options.debug = true
    return options
}()

private func startSDK() {
    SentrySDK.start(options: sentryOptions)
}

struct WriteCorruptedEnvelopeError: Error {
    let message: String
}

private func writeCorruptedEnvelope() throws {
    guard let dsnHash = sentryOptions.parsedDsn?.getHash() else {
        throw WriteCorruptedEnvelopeError(message: "DSN hash is not available")
    }

    let envelopeFolder = "\(sentryOptions.cacheDirectoryPath)/io.sentry/\(dsnHash)/envelopes"
    let envelopePath = "\(envelopeFolder)/corrupted-envelope.json"
    let corruptedEnvelopeData = Data("""
       {"event_id":"1990b5bc31904b7395fd07feb72daf1c","sdk":{"name":"sentry.cocoa","version":"8.33.0"}}
       {"type":"test","length":50}
       """.utf8)

    do {
        let fileManager = FileManager.default
        try fileManager.createDirectory(atPath: envelopeFolder, withIntermediateDirectories: true)
        try corruptedEnvelopeData.write(to: URL(fileURLWithPath: envelopePath), options: .atomic)
    } catch {
        throw WriteCorruptedEnvelopeError(message: "Error while writing corrupted envelope to: \(envelopePath) error: \(error)")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
