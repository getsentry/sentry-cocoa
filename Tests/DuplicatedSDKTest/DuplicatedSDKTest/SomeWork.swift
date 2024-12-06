import Sentry

class SomeWork {
    func doSomeWork() {
        SentrySDK.capture(message: "Some work")
    }
}
