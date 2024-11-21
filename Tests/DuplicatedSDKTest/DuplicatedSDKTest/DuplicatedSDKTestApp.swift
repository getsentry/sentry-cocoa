import ObjectiveC.runtime
import Sentry
import SwiftUI

@main
struct DuplicatedSDKTestApp: App {
    
    init () {
        SentrySDK.start { options in
            options.dsn = "https://a@o.sentry.io/1"
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
            Text("Test SentrySDK Integrations")
            Text("\(checkIntegrations())")
                .accessibilityIdentifier("TEST_RESULT")
        }
        .padding()
    }
    
    func checkIntegrations() -> Bool {
        guard let integrations = SentrySDK.currentHub().installedIntegrations else {
            return false
        }
        
        guard let sentryImageC = class_getImageName(SentrySDK.self) else {
            return false
        }
        let sentryImage = String(cString: sentryImageC)
        
        return integrations.allSatisfy({ element in
            guard let integrationImageC = class_getImageName(type(of: element as AnyObject)) else { return false }
            return sentryImage == String(cString: integrationImageC)
        })
    }
}

#Preview {
    ContentView()
}
