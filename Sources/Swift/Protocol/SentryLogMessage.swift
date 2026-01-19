import Foundation

/// A string type that supports structured logging with interpolation tracking.
///
/// `SentryLogMessage` captures both the final message and the interpolated values
/// as structured attributes, enabling better log analysis and searchability.
///
/// Example:
/// ```swift
/// let userId = 123
/// let userName = "john_doe"
/// let logString: SentryLogMessage = "User \(userId) with name \(userName) authenticated"
/// // Results in:
/// // - message: "User 123 with name john_doe authenticated"
/// // - template: "User {0} with name {1} authenticated"
/// // - attributes: [.init(integer: 123), .init(string: "john_doe")]
/// ```
public struct SentryLogMessage: ExpressibleByStringInterpolation {
    /// The final formatted message with all interpolations resolved
    let message: String
    /// Structured attributes extracted from interpolated values
    let attributes: [SentryLog.Attribute]
    /// Template string with placeholders for interpolated values
    let template: String
    
    /// Creates a log message from a plain string literal.
    /// - Parameter value: The string literal value.
    public init(stringLiteral value: String) {
        self.message = value
        self.attributes = []
        self.template = value
    }
    
    /// Creates a log message from a string interpolation.
    /// - Parameter stringInterpolation: The string interpolation containing the message and attributes.
    public init(stringInterpolation: StringInterpolation) {
        self.message = stringInterpolation.message
        self.attributes = stringInterpolation.attributes
        self.template = stringInterpolation.template
    }
    
    /// Handles string interpolation for `SentryLogMessage`, capturing interpolated values as structured attributes.
    public struct StringInterpolation: StringInterpolationProtocol {
        var message: String = ""
        var attributes: [SentryLog.Attribute] = []
        var template: String = ""
        private var interpolationCount = 0
        
        /// Initializes the string interpolation with expected capacity hints.
        /// - Parameters:
        ///   - literalCapacity: The expected number of characters in the literal segments.
        ///   - interpolationCount: The expected number of interpolations.
        public init(literalCapacity: Int, interpolationCount: Int) {
            // Reserve 2x literal capacity to account for interpolated values which often
            // equal or exceed the size of literals, avoiding expensive reallocations
            message.reserveCapacity(literalCapacity * 2)
            attributes.reserveCapacity(interpolationCount)
            // Here we know the exact count, as the tempkate always adds `{i}`,
            // with i beeing the index to the literalCapacity
            template.reserveCapacity(literalCapacity + interpolationCount * 3)
        }
        
        /// Appends a literal segment to the message.
        /// - Parameter literal: The literal string segment.
        public mutating func appendLiteral(_ literal: String) {
            message.append(literal)
            template.append(literal)
        }
        
        /// Appends a string interpolation to the message.
        /// - Parameter value: The string value to interpolate.
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> String) {
            let actualValue = value()
            appendInterpolationValue(stringValue: actualValue, attributeFactory: .init(string: actualValue))
        }
        
        /// Appends a boolean interpolation to the message.
        /// - Parameter value: The boolean value to interpolate.
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Bool) {
            let actualValue = value()
            appendInterpolationValue(stringValue: String(actualValue), attributeFactory: .init(boolean: actualValue))
        }
        
        /// Appends an integer interpolation to the message.
        /// - Parameter value: The integer value to interpolate.
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Int) {
            let actualValue = value()
            appendInterpolationValue(stringValue: String(actualValue), attributeFactory: .init(integer: actualValue))
        }
        
        /// Appends a double interpolation to the message.
        /// - Parameter value: The double value to interpolate.
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Double) {
            let actualValue = value()
            appendInterpolationValue(stringValue: String(actualValue), attributeFactory: .init(double: actualValue))
        }
        
        /// Appends a float interpolation to the message.
        /// - Parameter value: The float value to interpolate.
        public mutating func appendInterpolation(_ value: @autoclosure @escaping () -> Float) {
            let actualValue = value()
            appendInterpolationValue(stringValue: String(actualValue), attributeFactory: .init(double: Double(actualValue)))
        }
        
        /// Appends any `CustomStringConvertible` value to the message.
        /// - Parameter value: The value to interpolate.
        public mutating func appendInterpolation<T: CustomStringConvertible>(_ value: @autoclosure @escaping () -> T) {
            let actualValue = value()
            appendInterpolationValue(stringValue: actualValue.description, attributeFactory: .init(string: actualValue.description))
        }
        
        // Helper
        
        private mutating func appendInterpolationValue(
            stringValue: String,
            attributeFactory: @autoclosure () -> SentryLog.Attribute
        ) {
            // Add the value to the message
            message.append(stringValue)
            
            // Create placeholder in template
            template.append("{\(interpolationCount)}")
            
            // Add attribute for structured logging
            attributes.append(attributeFactory())
            
            interpolationCount += 1
        }
    }
}
