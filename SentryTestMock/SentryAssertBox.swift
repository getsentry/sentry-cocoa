import XCTest

public struct SentryAssertBox<ReturnValue> {
    internal let mock: MockFunction0<ReturnValue>

    internal init(_ mock: MockFunction0<ReturnValue>) {
        self.mock = mock
    }

    public func toHaveBeenCalled(file: StaticString = #file, line: UInt = #line) {
        guard !mock.calls.isEmpty else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }

    public func toHaveBeenCalledTimes(_ times: Int, file: StaticString = #file, line: UInt = #line) {
        guard mock.calls.count == times else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }
}

public struct SentryAssertBox1<ReturnValue, Arg1> {
    internal let mock: MockFunction1<ReturnValue, Arg1>

    internal init(_ mock: MockFunction1<ReturnValue, Arg1>) {
        self.mock = mock
    }

    public func toHaveBeenCalled(file: StaticString = #file, line: UInt = #line) {
        guard !mock.calls.isEmpty else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }

    public func toHaveBeenCalledTimes(_ times: Int, file: StaticString = #file, line: UInt = #line) {
        guard mock.calls.count == times else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }

    public func toHaveBeenCalledWith(_ arg1: Arg1, file: StaticString = #file, line: UInt = #line) where Arg1: Equatable {
        guard !mock.calls.isEmpty else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
        guard mock.calls.contains(where: { $0.arg1 == arg1 }) else {
            return XCTFail("Method has not been called with argument: \(arg1)", file: file, line: line)
        }
    }
}

public struct SentryAssertBox2<ReturnValue, Arg1, Arg2> {
    internal let mock: MockFunction2<ReturnValue, Arg1, Arg2>

    internal init(_ mock: MockFunction2<ReturnValue, Arg1, Arg2>) {
        self.mock = mock
    }

    public func toHaveBeenCalled(file: StaticString = #file, line: UInt = #line) {
        guard !mock.calls.isEmpty else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }

    public func toHaveBeenCalledTimes(_ times: Int, file: StaticString = #file, line: UInt = #line) {
        guard mock.calls.count == times else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
    }

    public func toHaveBeenCalledWith(_ arg1: Arg1, _ arg2: Arg2, file: StaticString = #file, line: UInt = #line) where Arg1: Equatable, Arg2: Equatable {
        guard !mock.calls.isEmpty else {
            return XCTFail("Method has not been called", file: file, line: line)
        }
        guard mock.calls.contains(where: { $0.arg1 == arg1 && $0.arg2 == arg2 }) else {
            return XCTFail("Method has not been called with arguments: \(arg1), \(arg2)", file: file, line: line)
        }
    }
}
