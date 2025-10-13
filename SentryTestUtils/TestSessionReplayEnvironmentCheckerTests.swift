@_spi(Private) @testable import Sentry

@_spi(Private) public class TestSessionReplayEnvironmentChecker: SentrySessionReplayEnvironmentCheckerProvider {

    public var isReliableInvocations = Invocations<Void>()
    private var mockedIsReliableReturnValue: Bool?

    public init() {}

    public func isReliable() -> Bool {
        isReliableInvocations.record(())
        guard let result = mockedIsReliableReturnValue else {
            preconditionFailure("\(Self.self): No mocked return value set for isReliable()")
        }
        return result
    }

    public func mockIsReliableReturnValue(_ returnValue: Bool) {
        mockedIsReliableReturnValue = returnValue
    }
}
