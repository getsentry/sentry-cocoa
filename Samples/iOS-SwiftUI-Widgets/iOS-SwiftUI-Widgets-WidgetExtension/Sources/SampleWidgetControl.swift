import AppIntents
import Sentry
import SentrySampleShared
import SwiftUI
import WidgetKit

struct SampleWidgetControl: ControlWidget {
   static let kind: String = "SampleWidgetControl"

    init() {
        setupSentrySDK()
    }

    private func setupSentrySDK() {
        guard !SentrySDK.isEnabled else {
            return
        }
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true
            options.enableAppHangTracking = true
        }
    }

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            provider: Provider()
        ) { value in
            ControlWidgetButton(
                action: RefreshStatusIntent()
            ) {
                Label("ANR Tracking", systemImage: value.isOn ? "checkmark.circle.fill" : "xmark.circle.fill")
            }
        }
        .displayName("Sentry ANR")
        .description("Refresh ANR status")
    }
}

extension SampleWidgetControl {
    struct Value {
        var isOn: Bool
    }

    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: ANRConfiguration) -> Value {
            Value(isOn: true) // Preview shows checkmark (ANR disabled, which is good)
        }

        func currentValue(configuration: ANRConfiguration) async throws -> Value {
            // Check if ANR tracking is installed
            let anrInstalled = SentrySDK.isEnabled &&
                SentrySDKInternal.trimmedInstalledIntegrationNames()
                    .contains("ANRTracking")
            
            // isOn = true means ANR is disabled (good for widgets)
            // isOn = false means ANR is enabled (bad for widgets)
            return Value(isOn: !anrInstalled)
        }
    }
}

struct ANRConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource { "ANR Status" }
    static var description: IntentDescription { "Configure ANR tracking status" }
}

struct RefreshStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Status"

    init() {}

    func perform() async throws -> some IntentResult {
        // Trigger widget refresh to show updated status
        await WidgetCenter.shared.reloadTimelines(ofKind: SampleWidgetControl.kind)
        return .result()
    }
}
