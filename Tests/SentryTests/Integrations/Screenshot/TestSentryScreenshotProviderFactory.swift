@testable import Sentry
import SentryTestUtils

class TestSentryScreenshotProviderFactory: SentryScreenshotProviderFactory {
    var getScreenshotProviderForOptionsInvocations = Invocations<SentryScreenshotOptions>()
    var getScreenshotProviderForOptionsReturnValue: SentryScreenshotProvider?

    override func getScreenshotProviderForOptions(_ options: SentryScreenshotOptions) -> SentryScreenshotProvider {
        getScreenshotProviderForOptionsInvocations.record(options)
        if let returnValue = getScreenshotProviderForOptionsReturnValue {
            return returnValue
        }
        return super.getScreenshotProviderForOptions(options)
    }
}
