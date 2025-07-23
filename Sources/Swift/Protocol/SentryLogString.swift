import Foundation

/// A string type that supports structured logging with interpolation tracking.
///
/// `SentryLogString` captures both the final message and the interpolated values
/// as structured attributes, enabling better log analysis and searchability.
/// Private values are replaced with "<private>" in the message for privacy protection.
///
/// Example:
/// ```swift
/// let userId = 123
/// let sessionToken = "abc123xyz"
/// let logString: SentryLogString = "User \(userId) authenticated with token \(sessionToken, privacy: .private)"
/// // Results in:
/// // - message: "User 123 authenticated with token <private>"
/// // - template: "User {0} authenticated with token {1}"
/// // - attributes: [.integer(123)] // Only public values are captured
/// ```
public struct SentryLogString: ExpressibleByStringInterpolation {
    public enum Privacy {
        case `public`
        case `private`
    }

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
        
        // MARK: - Supported SentryLog.Attribute types with privacy control
        
        /// Append String interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> String, privacy: SentryLogString.Privacy = .`public`) {
            let actualValue = value()
            
            // Private values are replaced with "<private>" in the message
            if privacy == .`public` {
                message.append(actualValue)
            } else {
                message.append("<private>")
            }
            
            // Both public and private values create placeholders in template
            template.append("{\(interpolationCount)}")
            
            // Only public values are added to attributes for structured logging
            if privacy == .`public` {
                attributes.append(.string(actualValue))
            }
            
            interpolationCount += 1
        }
        
        /// Append Bool interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Bool, privacy: SentryLogString.Privacy = .`public`) {
            let actualValue = value()
            
            // Private values are replaced with "<private>" in the message
            if privacy == .`public` {
                let stringValue = String(actualValue)
                message.append(stringValue)
            } else {
                message.append("<private>")
            }
            
            // Both public and private values create placeholders in template
            template.append("{\(interpolationCount)}")
            
            // Only public values are added to attributes for structured logging
            if privacy == .`public` {
                attributes.append(.boolean(actualValue))
            }
            
            interpolationCount += 1
        }
        
        /// Append Int interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Int, privacy: SentryLogString.Privacy = .`public`) {
            let actualValue = value()
            
            // Private values are replaced with "<private>" in the message
            if privacy == .`public` {
                let stringValue = String(actualValue)
                message.append(stringValue)
            } else {
                message.append("<private>")
            }
            
            // Both public and private values create placeholders in template
            template.append("{\(interpolationCount)}")
            
            // Only public values are added to attributes for structured logging
            if privacy == .`public` {
                attributes.append(.integer(actualValue))
            }
            
            interpolationCount += 1
        }
        
        /// Append Double interpolation
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Double, privacy: SentryLogString.Privacy = .`public`) {
            let actualValue = value()
            
            // Private values are replaced with "<private>" in the message
            if privacy == .`public` {
                let stringValue = String(actualValue)
                message.append(stringValue)
            } else {
                message.append("<private>")
            }
            
            // Both public and private values create placeholders in template
            template.append("{\(interpolationCount)}")
            
            // Only public values are added to attributes for structured logging
            if privacy == .`public` {
                attributes.append(.double(actualValue))
            }
            
            interpolationCount += 1
        }
        
        /// Append Float interpolation (converted to Double)
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Float, privacy: SentryLogString.Privacy = .`public`) {
            let actualValue = value()
            
            // Private values are replaced with "<private>" in the message
            if privacy == .`public` {
                let stringValue = String(actualValue)
                message.append(stringValue)
            } else {
                message.append("<private>")
            }
            
            // Both public and private values create placeholders in template
            template.append("{\(interpolationCount)}")
            
            // Only public values are added to attributes for structured logging
            if privacy == .`public` {
                attributes.append(.double(Double(actualValue)))
            }
            
            interpolationCount += 1
        }
    }
}
