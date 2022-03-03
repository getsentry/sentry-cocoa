import Foundation
import Sentry

func clearTestState() {
    SentrySDK.close()
}
