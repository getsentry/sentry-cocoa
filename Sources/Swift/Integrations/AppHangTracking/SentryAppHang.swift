/// A hang event derived from a run loop delay that exceeded an observer's threshold.
struct SentryAppHang {
    enum State {
        case started
        case ended
    }

    let duration: TimeInterval
    let state: State
}
