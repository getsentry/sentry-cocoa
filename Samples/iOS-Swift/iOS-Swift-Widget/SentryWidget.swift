import SentrySampleShared
import SwiftUI
import WidgetKit

struct SentryProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SentryWidgetTimelineEntry {
        SentryWidgetTimelineEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SentryWidgetTimelineEntry {
        SentryWidgetTimelineEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SentryWidgetTimelineEntry> {
        var entries: [SentryWidgetTimelineEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SentryWidgetTimelineEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }
}

struct SentryWidgetTimelineEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct SentryWidgetEntryView: View {
    var entry: SentryProvider.Entry

    var body: some View {
        VStack {
            Text("Time:")
            Text(entry.date, style: .time)

            Text("Favorite Emoji:")
            Text(entry.configuration.favoriteEmoji)
        }
    }
}

struct SentryWidget: Widget {
    let kind: String = "SentryWidget"

    init() {
        SentrySDKWrapper.shared.startSentry()
    }

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: SentryProvider()) { entry in
            SentryWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    SentryWidget()
} timeline: {
    SentryWidgetTimelineEntry(date: .now, configuration: .smiley)
    SentryWidgetTimelineEntry(date: .now, configuration: .starEyes)
}
