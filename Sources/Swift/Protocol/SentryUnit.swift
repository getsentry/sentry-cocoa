/// Type-safe units for telemetry data (Metrics, Spans, and Logs).
///
/// These units help Sentry display metric values in a human-readable format.
/// Use the predefined cases for common units, or `.generic("custom")` for custom units.
///
/// - SeeAlso: https://develop.sentry.dev/sdk/telemetry/attributes/#units
public enum SentryUnit: Equatable {
    // MARK: - Duration Units

    /// Nanosecond duration unit.
    case nanosecond
    /// Microsecond duration unit.
    case microsecond
    /// Millisecond duration unit.
    case millisecond
    /// Second duration unit.
    case second
    /// Minute duration unit.
    case minute
    /// Hour duration unit.
    case hour
    /// Day duration unit.
    case day
    /// Week duration unit.
    case week

    // MARK: - Information Units

    /// Bit information unit.
    case bit
    /// Byte information unit.
    case byte
    /// Kilobyte information unit (1000 bytes).
    case kilobyte
    /// Kibibyte information unit (1024 bytes).
    case kibibyte
    /// Megabyte information unit (1000^2 bytes).
    case megabyte
    /// Mebibyte information unit (1024^2 bytes).
    case mebibyte
    /// Gigabyte information unit (1000^3 bytes).
    case gigabyte
    /// Gibibyte information unit (1024^3 bytes).
    case gibibyte
    /// Terabyte information unit (1000^4 bytes).
    case terabyte
    /// Tebibyte information unit (1024^4 bytes).
    case tebibyte
    /// Petabyte information unit (1000^5 bytes).
    case petabyte
    /// Pebibyte information unit (1024^5 bytes).
    case pebibyte
    /// Exabyte information unit (1000^6 bytes).
    case exabyte
    /// Exbibyte information unit (1024^6 bytes).
    case exbibyte

    // MARK: - Fraction Units

    /// Ratio fraction unit (value between 0 and 1).
    case ratio
    /// Percent fraction unit (value between 0 and 100).
    case percent

    // MARK: - Generic

    /// Custom unit with a string value.
    case generic(String)
}

// MARK: - RawRepresentable
//
// We implement RawRepresentable manually instead of using `enum SentryUnit: String` because
// the enum includes `.generic(String)` for custom unit values. Swift's automatic String raw value
// synthesis doesn't support associated values, so we need this custom implementation to:
// 1. Map known unit strings to their corresponding enum cases
// 2. Fall back to `.generic(rawValue)` for any unrecognized string (custom units)

extension SentryUnit: RawRepresentable {
    /// The string representation of the unit.
    public typealias RawValue = String

    /// Creates a unit from its string representation.
    ///
    /// Maps known unit strings to their corresponding enum cases, or falls back to
    /// `.generic(rawValue)` for any unrecognized string (custom units).
    public init?(rawValue: String) { // swiftlint:disable:this cyclomatic_complexity function_body_length
        switch rawValue {
        // Duration Units
        case "nanosecond":
            self = .nanosecond
        case "microsecond":
            self = .microsecond
        case "millisecond":
            self = .millisecond
        case "second":
            self = .second
        case "minute":
            self = .minute
        case "hour":
            self = .hour
        case "day":
            self = .day
        case "week":
            self = .week

        // Information Units
        case "bit":
            self = .bit
        case "byte":
            self = .byte
        case "kilobyte":
            self = .kilobyte
        case "kibibyte":
            self = .kibibyte
        case "megabyte":
            self = .megabyte
        case "mebibyte":
            self = .mebibyte
        case "gigabyte":
            self = .gigabyte
        case "gibibyte":
            self = .gibibyte
        case "terabyte":
            self = .terabyte
        case "tebibyte":
            self = .tebibyte
        case "petabyte":
            self = .petabyte
        case "pebibyte":
            self = .pebibyte
        case "exabyte":
            self = .exabyte
        case "exbibyte":
            self = .exbibyte

        // Fraction Units
        case "ratio":
            self = .ratio
        case "percent":
            self = .percent

        // Generic - any other string value
        default:
            self = .generic(rawValue)
        }
    }

    /// Returns the string representation of the unit.
    public var rawValue: String {
        switch self {
        // Duration Units
        case .nanosecond:
            return "nanosecond"
        case .microsecond:
            return "microsecond"
        case .millisecond:
            return "millisecond"
        case .second:
            return "second"
        case .minute:
            return "minute"
        case .hour:
            return "hour"
        case .day:
            return "day"
        case .week:
            return "week"

        // Information Units
        case .bit:
            return "bit"
        case .byte:
            return "byte"
        case .kilobyte:
            return "kilobyte"
        case .kibibyte:
            return "kibibyte"
        case .megabyte:
            return "megabyte"
        case .mebibyte:
            return "mebibyte"
        case .gigabyte:
            return "gigabyte"
        case .gibibyte:
            return "gibibyte"
        case .terabyte:
            return "terabyte"
        case .tebibyte:
            return "tebibyte"
        case .petabyte:
            return "petabyte"
        case .pebibyte:
            return "pebibyte"
        case .exabyte:
            return "exabyte"
        case .exbibyte:
            return "exbibyte"

        // Fraction Units
        case .ratio:
            return "ratio"
        case .percent:
            return "percent"

        // Generic
        case .generic(let value):
            return value
        }
    }
}

extension SentryUnit: Encodable {
    /// Encodes the unit as its string representation.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension SentryUnit: ExpressibleByStringLiteral {
    /// Creates a generic unit from a string literal.
    public init(stringLiteral value: StringLiteralType) {
        self = .generic(value)
    }
}
