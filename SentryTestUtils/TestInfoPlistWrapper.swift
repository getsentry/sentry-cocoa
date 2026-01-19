@_spi(Private) @testable import Sentry
import XCTest

@_spi(Private) public class TestInfoPlistWrapper: SentryInfoPlistWrapperProvider {

    public var getAppValueStringInvocations = Invocations<String>()
    private var mockedGetAppValueStringReturnValue: [String: Result<String, Error>] = [:]

    public var getAppValueBooleanInvocations = Invocations<(String, NSErrorPointer)>()
    private var mockedGetAppValueBooleanReturnValue: [String: Result<Bool, NSError>] = [:]

    public init() {}

    public func mockGetAppValueStringReturnValue(forKey key: String, value: String) {
        mockedGetAppValueStringReturnValue[key] = .success(value)
    }

    public func mockGetAppValueStringThrowError(forKey key: String, error: Error) {
        mockedGetAppValueStringReturnValue[key] = .failure(error)
    }

    public func getAppValueString(for key: String) throws -> String {
        getAppValueStringInvocations.record(key)
        guard let result = mockedGetAppValueStringReturnValue[key] else {
            XCTFail("TestInfoPlistWrapper: No mocked return value set for getAppValueString(for:) for key: \(key)")
            return "<not set>"
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        }
    }

    public func mockGetAppValueBooleanReturnValue(forKey key: String, value: Bool) {
        mockedGetAppValueBooleanReturnValue[key] = .success(value)
    }

    public func mockGetAppValueBooleanThrowError(forKey key: String, error: NSError) {
        mockedGetAppValueBooleanReturnValue[key] = .failure(error)
    }

    public func getAppValueBoolean(for key: String, errorPtr: NSErrorPointer) -> Bool {
        getAppValueBooleanInvocations.record((key, errorPtr))
        guard let result = mockedGetAppValueBooleanReturnValue[key] else {
            XCTFail("TestInfoPlistWrapper: No mocked return value set for getAppValueBoolean(for:) for key: \(key)")
            return false
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
