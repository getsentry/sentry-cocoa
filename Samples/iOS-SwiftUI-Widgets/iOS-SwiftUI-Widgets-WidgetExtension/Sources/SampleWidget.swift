@_spi(Private) @testable import Sentry
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
        let anrInstalled = SentrySDK.isEnabled &&
        SentrySDKInternal.trimmedInstalledIntegrationNames()
            .contains("ANRTracking")

        VStack(spacing: 8) {
            Text("Sentry")
                .font(.headline)

            Text("ANR Tracking:")
                .font(.caption2)
            Text(anrInstalled ? "❌ Enabled" : "✅ Disabled")
                .font(.caption)
                .foregroundColor(anrInstalled ? .red : .green)
                .bold()

            Text(entry.date, style: .time)
                .font(.caption2)
        }
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
        guard !SentrySDK.isEnabled else {
            return
        }
        SentrySDK.start { options in
            options.dsn = "https://a92d50327ac74b8b9aa4ea80eccfb267@o447951.ingest.sentry.io/5428557"
            options.debug = true
            options.enableAppHangTracking = true
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: SampleConfigurationAppIntent
}
