
import Sentry

class SomeWorkB {
    func doSomeWork() {
        SentrySDK.capture(message: "Some work B")
    }
}
