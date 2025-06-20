@objcMembers
public final class SentryLogAttribute {
    public let value: Any
    public let type: String
    
    public init(value: Any, type: String) {
        self.value = value
        self.type = type
    }
    
    static func string(_ value: String) -> SentryLogAttribute {
        return SentryLogAttribute(value: value, type: "string")
    }
    
    static func bool(_ value: Bool) -> SentryLogAttribute {
        return SentryLogAttribute(value: value, type: "boolean")
    }
    
    static func int(_ value: Int) -> SentryLogAttribute {
        return SentryLogAttribute(value: value, type: "integer")
    }
    
    static func double(_ value: Double) -> SentryLogAttribute {
        return SentryLogAttribute(value: value, type: "double")
    }
}
