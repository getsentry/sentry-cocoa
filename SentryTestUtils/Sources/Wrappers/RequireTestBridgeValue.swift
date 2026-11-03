import XCTest

// A wrong type is a broken bridge contract, not a recoverable SDK error. Keep that failure
// inside the test support instead of changing the SDK's nonthrowing APIs or inventing defaults.
// This intentionally terminates the test process on a contract violation.
func requireTestBridgeValue<Value>(_ value: Any, file: StaticString = #file, line: UInt = #line) -> Value {
    guard let typedValue = value as? Value else {
        let message = "Test bridge expected \(Value.self), got \(type(of: value))"
        XCTFail(message, file: file, line: line)
        preconditionFailure(message, file: file, line: line)
    }
    return typedValue
}
