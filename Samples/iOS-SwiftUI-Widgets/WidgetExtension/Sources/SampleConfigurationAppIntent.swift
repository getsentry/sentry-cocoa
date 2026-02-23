import AppIntents
import WidgetKit

struct SampleConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Configuration" }
    static var description: IntentDescription { "This is a Sentry widget." }
}
