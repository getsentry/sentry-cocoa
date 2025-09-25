@_spi(Private) @testable import Sentry

public extension SentryLog.Attribute {
    
    func equal(to other: SentryLog.Attribute) -> Bool {
        guard type == other.type else {
            return false
        }
        // Compare values based on type
        switch type {
        case "string":
            let expectedValue = value as! String
            let actualValue = other.value as! String
            return expectedValue == actualValue
        case "boolean":
            let expectedValue = value as! Bool
            let actualValue = other.value as! Bool
            return expectedValue == actualValue
        case "integer":
            let expectedValue = value as! Int
            let actualValue = other.value as! Int
            return expectedValue == actualValue
        case "double":
            let expectedValue = value as! Double
            let actualValue = other.value as! Double
            return expectedValue == actualValue
        default:
            return false
        }
    }
}
