import Foundation

/// A string type that supports structured logging with interpolation tracking.
///
/// `SentryLogString` captures both the final message and the interpolated values
/// as structured attributes, enabling better log analysis and searchability.
///
/// Example:
/// ```swift
/// let userId = 123
/// let username = "john_doe"
/// let logString: SentryLogString = "User \(userId) logged in as \(username)"
/// // Results in:
/// // - message: "User 123 logged in as john_doe"
/// // - template: "User {0} logged in as {1}"
/// // - attributes: [.integer(123), .string("john_doe")]
/// ```
public struct SentryLogString: ExpressibleByStringInterpolation {
    /// The final formatted message with all interpolations resolved
    let message: String
    /// Structured attributes extracted from interpolated values
    let attributes: [SentryLog.Attribute]
    /// Template string with placeholders for interpolated values
    let template: String
    
    public init(stringLiteral value: String) {
        self.message = value
        self.attributes = []
        self.template = value
    }
    
    public init(stringInterpolation: StringInterpolation) {
        self.message = stringInterpolation.message
        self.attributes = stringInterpolation.attributes
        self.template = stringInterpolation.template
    }
    
    public struct StringInterpolation: StringInterpolationProtocol {
        var message: String = ""
        var attributes: [SentryLog.Attribute] = []
        var template: String = ""
        private var interpolationCount = 0
        
        public init(literalCapacity: Int, interpolationCount: Int) {
            message.reserveCapacity(literalCapacity * 2)
            attributes.reserveCapacity(interpolationCount)
            template.reserveCapacity(literalCapacity * 2)
        }
        
        public mutating func appendLiteral(_ literal: String) {
            message.append(literal)
            template.append(literal)
        }
        
        // MARK: - Supported SentryLog.Attribute types only
        
        /// Append String interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> String) {
            let actualValue = value()
            message.append(actualValue)
            template.append("{\(interpolationCount)}")
            attributes.append(.string(actualValue))
            interpolationCount += 1
        }
        
        /// Append Bool interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Bool) {
            let actualValue = value()
            message.append(String(actualValue))
            template.append("{\(interpolationCount)}")
            attributes.append(.boolean(actualValue))
            interpolationCount += 1
        }
        
        /// Append Int interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Int) {
            let actualValue = value()
            message.append(String(actualValue))
            template.append("{\(interpolationCount)}")
            attributes.append(.integer(actualValue))
            interpolationCount += 1
        }
        
        /// Append Double interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Double) {
            let actualValue = value()
            message.append(String(actualValue))
            template.append("{\(interpolationCount)}")
            attributes.append(.double(actualValue))
            interpolationCount += 1
        }
        
        /// Append Float interpolation (converted to Double)
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Float) {
            let actualValue = value()
            message.append(String(actualValue))
            template.append("{\(interpolationCount)}")
            attributes.append(.double(Double(actualValue)))
            interpolationCount += 1
        }
        
        /// Append interpolation without tracking (for any other type or sensitive data)
        ///
        /// Use this for values that shouldn't be captured as structured attributes,
        /// such as sensitive data or unsupported types.
        ///
        /// Example:
        /// ```swift
        /// let logString: SentryLogString = "Processing \(untracked: sensitiveToken)"
        /// ```
        public mutating func appendInterpolation<T>(untracked value: T) {
            message.append(String(describing: value))
            template.append(String(describing: value))
        }
    }
}
