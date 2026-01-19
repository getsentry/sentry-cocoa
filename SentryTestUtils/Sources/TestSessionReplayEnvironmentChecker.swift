@_spi(Private) @testable import Sentry

@_spi(Private) public class TestSessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentCheckerProvider {

    public var isReliableInvocations = Invocations<Void>()
    private var mockedIsReliableReturnValue: Bool

    public init(
        mockedIsReliableReturnValue: Bool
    ) {
        self.mockedIsReliableReturnValue = mockedIsReliableReturnValue
    }

    public func isReliable() -> Bool {
        isReliableInvocations.record(())
        return mockedIsReliableReturnValue
    }

    public func mockIsReliableReturnValue(_ returnValue: Bool) {
        mockedIsReliableReturnValue = returnValue
    }
}
