// swiftlint:disable missing_docs
#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

extension SentryBreadcrumbTracker {
    static func extractData(
        from view: UIView,
        includeAccessibilityIdentifier: Bool,
        redactBuilder: SentryUIRedactBuilder?,
        extractChildText: Bool = false
    ) -> [String: Any] {
        var result: [String: Any] = ["view": SwiftDescriptor.getSanitizedViewDescription(view)]

        if view.tag > 0 {
            result["tag"] = view.tag
        }

        if includeAccessibilityIdentifier,
           let identifier = view.accessibilityIdentifier,
           !identifier.isEmpty {
            result["accessibilityIdentifier"] = identifier
        }

        if let button = view as? UIButton,
           let title = SentryChildTextExtractor.title(from: button),
           redactBuilder?.isViewMaskedForTextExtraction(button.titleLabel ?? button) != true {
            result["title"] = title
        }

        if extractChildText,
           result["accessibilityIdentifier"] == nil,
           result["title"] == nil,
           let label = SentryChildTextExtractor.extract(from: view, redactBuilder: redactBuilder) {
            result["label"] = label
        }

        return result
    }
}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
// swiftlint:enable missing_docs
