@_spi(Private) @testable import Sentry

@_spi(Private) public class TestInfoPlistWrapper: SentryInfoPlistWrapperProvider {

    public init() {}
    
    public var getAppValueStringInvocations = Invocations<String>()
    private var mockedGetAppValueStringReturnValue: [String: Result<String, Error>] = [:]

    public func mockGetAppValueStringReturnValue(forKey key: String, value: String) {
        mockedGetAppValueStringReturnValue[key] = .success(value)
    }

    public func mockGetAppValueStringThrowError(forKey key: String, error: Error) {
        mockedGetAppValueStringReturnValue[key] = .failure(error)
    }

    public func getAppValueString(for key: String) throws -> String {
        getAppValueStringInvocations.record(key)
        guard let result = mockedGetAppValueStringReturnValue[key] else {
            preconditionFailure("TestInfoPlistWrapper: No mocked return value set for getAppValueString(for:) for key: \(key)")
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    public var getAppValueBooleanInvocations = Invocations<(String, NSErrorPointer)>()
    private var mockedGetAppValueBooleanReturnValue: [String: Result<Bool, NSError>] = [:]

    public func mockGetAppValueBooleanReturnValue(forKey key: String, value: Bool) {
        mockedGetAppValueBooleanReturnValue[key] = .success(value)
    }

    public func mockGetAppValueBooleanThrowError(forKey key: String, error: NSError) {
        mockedGetAppValueBooleanReturnValue[key] = .failure(error)
    }

    public func getAppValueBoolean(for key: String, errorPtr: NSErrorPointer) -> Bool {
        getAppValueBooleanInvocations.record((key, errorPtr))
        guard let result = mockedGetAppValueBooleanReturnValue[key] else {
            preconditionFailure("TestInfoPlistWrapper: No mocked return value set for getAppValueBoolean(for:) for key: \(key)")
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            errorPtr?.pointee = error
            return false
        }
    }
}
