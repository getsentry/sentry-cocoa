import Foundation

extension SentryThread {
    open override func isEqual(_ object: Any?) -> Bool {
        if  let other = object as? SentryThread {
            return  threadId == other.threadId &&
                name == other.name &&
                stacktrace == other.stacktrace &&
                crashed == other.crashed && current == other.current
        } else {
            return false
        }
    }
    
    override open var description: String {
        "\(self.serialize())"
    }
}

extension Stacktrace {
    open override func isEqual(_ object: Any?) -> Bool {
        if  let other = object as? Stacktrace {
            return frames == other.frames &&
                registers == other.registers
        } else {
            return false
        }
    }
    
    override open var description: String {
        "\(self.serialize())"
    }
}

extension Frame {
    open override func isEqual(_ object: Any?) -> Bool {
        if  let other = object as? Frame {
            return symbolAddress == other.symbolAddress &&
                fileName == other.fileName &&
                function == other.function &&
                module == other.module &&
                package == other.package &&
                imageAddress == other.imageAddress &&
                platform == other.platform &&
                instructionAddress == other.instructionAddress &&
                lineNumber == other.lineNumber &&
                columnNumber == other.columnNumber &&
                inApp == other.inApp
        } else {
            return false
        }
    }
    
    override open var description: String {
        "\(self.serialize())"
    }
}
