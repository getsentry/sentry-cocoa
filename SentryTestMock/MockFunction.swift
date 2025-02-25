import XCTest

public struct MockFunction0<ReturnValue> {
    internal var calls: [CallBox0<ReturnValue>] = []

    private var mockedImplementation: (() -> ReturnValue)?

    public init() {}

    public mutating func clear() {
        mockedImplementation = nil
    }

    public mutating func returnValue(_ value: ReturnValue) {
        mockedImplementation = { value }
    }

    public mutating func returnValueOnce(_ value: ReturnValue) {
        mockedImplementation = { value }
    }

    public mutating func useImplementation(_ implementation: @escaping () -> ReturnValue) {
        mockedImplementation = implementation
    }

    public mutating func call(default defaultImplementation: @autoclosure () -> ReturnValue) -> ReturnValue {
        let returnValue: ReturnValue
        if let mockedImplementation = mockedImplementation {
            returnValue = mockedImplementation()
        } else {
            returnValue = defaultImplementation()
        }
        calls.append(CallBox0(returnValue: returnValue))
        return returnValue
    }
}

public struct MockFunction1<ReturnValue, Arg1> {
    internal var calls: [CallBox1<ReturnValue, Arg1>] = []

    private var mockedImplementation: ((_ arg1: Arg1) -> ReturnValue)?

    public init() {}

    public mutating func clear() {
        mockedImplementation = nil
    }

    public mutating func returnValue(_ value: ReturnValue) {
        mockedImplementation = { _ in value }
    }

    public mutating func returnValueOnce(_ value: ReturnValue) {
        mockedImplementation = { _ in value }
    }

    public mutating func useImplementation(_ implementation: @escaping (_ arg1: Arg1) -> ReturnValue) {
        mockedImplementation = implementation
    }

    public mutating func call(_ arg1: Arg1, default defaultImplementation: (_ arg1: Arg1) -> ReturnValue) -> ReturnValue {
        let returnValue: ReturnValue
        if let mockedImplementation = mockedImplementation {
            returnValue = mockedImplementation(arg1)
        } else {
            returnValue = defaultImplementation(arg1)
        }
        calls.append(CallBox1(returnValue: returnValue, arg1: arg1))
        return returnValue
    }
}

public struct MockFunction2<ReturnValue, Arg1, Arg2> {
    internal var calls: [CallBox2<ReturnValue, Arg1, Arg2>] = []

    private var mockedImplementation: ((_ arg1: Arg1, _ arg2: Arg2) -> ReturnValue)?

    public init() {}

    public mutating func clear() {
        mockedImplementation = nil
    }

    public mutating func returnValue(_ value: ReturnValue) {
        mockedImplementation = { _, _ in value }
    }

    public mutating func returnValueOnce(_ value: ReturnValue) {
        mockedImplementation = { _, _ in value }
    }

    public mutating func call(_ arg1: Arg1, _ arg2: Arg2, default defaultImplementation: (_ arg1: Arg1, _ arg2: Arg2) -> ReturnValue) -> ReturnValue {
        let returnValue: ReturnValue
        if let mockedImplementation = mockedImplementation {
            returnValue = mockedImplementation(arg1, arg2)
        } else {
            returnValue = defaultImplementation(arg1, arg2)
        }
        calls.append(CallBox2(returnValue: returnValue, arg1: arg1, arg2: arg2))
        return returnValue
    }
}
