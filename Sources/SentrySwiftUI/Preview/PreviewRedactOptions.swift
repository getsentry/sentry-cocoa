#if canImport(SwiftUI) && canImport(UIKit) && os(iOS) || os(tvOS)
import Sentry

public class PreviewRedactOptions: SentryRedactOptions {
    public let maskAllText: Bool
    public let maskAllImages: Bool
    public let maskedViewClasses: [AnyClass]
    public let unmaskedViewClasses: [AnyClass]

    public init(maskAllText: Bool = true, maskAllImages: Bool = true, maskedViewClasses: [AnyClass] = [], unmaskedViewClasses: [AnyClass] = []) {
        self.maskAllText = maskAllText
        self.maskAllImages = maskAllImages
        self.maskedViewClasses = maskedViewClasses
        self.unmaskedViewClasses = unmaskedViewClasses
    }
}

#endif
