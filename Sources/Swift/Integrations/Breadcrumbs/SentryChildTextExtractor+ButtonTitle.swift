#if (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
import UIKit

extension SentryChildTextExtractor {
    static func boundedTitle(from button: UIButton) -> String? {
        if let title = button.currentTitle, let text = boundedText(title) {
            return text
        }
        if let title = button.currentAttributedTitle {
            let bounded = title.attributedSubstring(
                from: NSRange(location: 0, length: min(title.length, maximumTextLength + 1))
            ).string
            if let text = boundedText(bounded) {
                return text
            }
        }
        if #available(iOS 15.0, tvOS 15.0, *) {
            if let title = button.configuration?.title, let text = boundedText(title) {
                return text
            }
            if let title = button.configuration?.attributedTitle {
                let bounded = String(title.characters.prefix(maximumTextLength + 1))
                if let text = boundedText(bounded) {
                    return text
                }
            }
        }
        return nil
    }

    static func boundedText(_ text: String) -> String? {
        let text = String(text.prefix(maximumTextLength + 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    static func title(from button: UIButton) -> String? {
        if let title = button.currentTitle, !title.isEmpty {
            return title
        }
        if let title = button.currentAttributedTitle, title.length > 0 {
            return boundedAttributedTitle(title)
        }
        if #available(iOS 15.0, tvOS 15.0, *) {
            if let title = button.configuration?.title, !title.isEmpty {
                return title
            }
            if let title = button.configuration?.attributedTitle, !title.characters.isEmpty {
                let text = String(title.characters.prefix(maximumTextLength + 1))
                guard text.count > maximumTextLength else { return text }
                return String(text.prefix(maximumTextLength)) + "..."
            }
        }
        return nil
    }

    private static func boundedAttributedTitle(_ title: NSAttributedString) -> String {
        let length = min(title.length, maximumTextLength + 1)
        let text = title.attributedSubstring(from: NSRange(location: 0, length: length)).string
        guard text.count > maximumTextLength else { return text }
        return String(text.prefix(maximumTextLength)) + "..."
    }
}
#endif // (os(iOS) || os(tvOS) || os(visionOS)) && !SENTRY_NO_UI_FRAMEWORK
