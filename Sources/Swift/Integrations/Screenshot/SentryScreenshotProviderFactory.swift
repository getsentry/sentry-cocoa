@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryScreenshotProviderFactory: NSObject {
    func getScreenshotProviderForOptions(_ options: SentryScreenshotOptions) -> SentryScreenshotProvider {
        SentryScreenshotProvider(
            options,
            enableViewRendererV2: options.enableViewRendererV2,
            enableFastViewRendering: options.enableFastViewRendering
        )
    }
}
