import Sentry
import SentrySampleShared
import SwiftUI
import WidgetKit

struct SampleWidget: Widget {
    let kind: String = "SampleWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SampleConfigurationAppIntent.self, provider: Provider()) { entry in
            SampleWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

fileprivate struct SampleWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(spacing: 8) {
            Text("Sentry")
                .font(.headline)

            Text("SDK Enabled? \(isSentryEnabled ? "✅" : "❌")")
                .font(.caption)
                .foregroundColor(isSentryEnabled ? .green : .red)
                .bold()
            Text("ANR Disabled? \(!isANRInstalled ? "✅" : "❌")")
                .font(.caption)
                .foregroundColor(!isANRInstalled ? .green : .red)
                .bold()

            Text(entry.date, style: .time)
                .font(.caption2)
        }
    }

    var isANRInstalled: Bool {
        return isSentryEnabled && SentrySDKInternal.trimmedInstalledIntegrationNames().contains("ANRTracking")
    }

    var isSentryEnabled: Bool {
        SentrySDK.isEnabled
    }
}

private struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: SampleConfigurationAppIntent())
    }

    func snapshot(for configuration: SampleConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        setupSentrySDK()

        return SimpleEntry(date: Date(), configuration: configuration)
    }

    func timeline(for configuration: SampleConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        setupSentrySDK()

        let entry = SimpleEntry(date: Date(), configuration: configuration)
        return Timeline(entries: [entry], policy: .atEnd)
    }

    private func setupSentrySDK() {
        // Prevent double initialization - SentrySDK.start() can be called multiple times
        // but we want to avoid unnecessary re-initialization
        guard !SentrySDK.isEnabled else {
            return
        }

        // For this extension we need a specific configuration set, therefore we do not use the shared sample initializer
        SentrySDK.start { options in
            options.dsn = SentrySDKWrapper.defaultDSN
            options.debug = true

            // App Hang Tracking must be enabled, but should not be installed
            options.enableAppHangTracking = true
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: SampleConfigurationAppIntent
}
