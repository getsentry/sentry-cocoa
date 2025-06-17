@_implementationOnly import _SentryPrivate
import Foundation

@objcMembers
class SentryScreenshotProviderFactory: NSObject {
    func getProviderForOptions(_ options: SentryScreenshotOptions) -> SentryScreenshotProvider {
        SentryScreenshotProvider(
            options,
            enableViewRendererV2: options.enableViewRendererV2,
            enableFastViewRendering: options.enableFastViewRendering
        )
    }
}
