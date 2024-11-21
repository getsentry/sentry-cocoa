
import Sentry

class SomeWorkA {
    func doSomeWork() {
        SentrySDK.capture(message: "Some work A")
    }
}
