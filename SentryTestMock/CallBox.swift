internal struct CallBox0<ReturnValue> {
    internal let returnValue: ReturnValue

    internal init(returnValue: ReturnValue) {
        self.returnValue = returnValue
    }
}

internal struct CallBox1<ReturnValue, Arg1> {
    internal let returnValue: ReturnValue
    internal let arg1: Arg1

    init(returnValue: ReturnValue, arg1: Arg1) {
        self.returnValue = returnValue
        self.arg1 = arg1
    }
}

internal struct CallBox2<ReturnValue, Arg1, Arg2> {
    internal let returnValue: ReturnValue
    internal let arg1: Arg1
    internal let arg2: Arg2

    internal init(returnValue: ReturnValue, arg1: Arg1, arg2: Arg2) {
        self.returnValue = returnValue
        self.arg1 = arg1
        self.arg2 = arg2
    }
}
