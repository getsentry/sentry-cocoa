public func sentryExpect<ReturnValue>(_ mock: MockFunction0<ReturnValue>) -> SentryAssertBox<ReturnValue> {
    SentryAssertBox(mock)
}

public func sentryExpect<ReturnValue, Arg1>(_ mock: MockFunction1<ReturnValue, Arg1>) -> SentryAssertBox1<ReturnValue, Arg1> {
    SentryAssertBox1(mock)
}

public func sentryExpect<ReturnValue, Arg1, Arg2>(_ mock: MockFunction2<ReturnValue, Arg1, Arg2>) -> SentryAssertBox2<ReturnValue, Arg1, Arg2> {
    SentryAssertBox2(mock)
}
