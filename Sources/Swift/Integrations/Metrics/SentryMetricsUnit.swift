/// Type used for known attribute units used by Metrics
///
/// - SeeAlso: https://develop.sentry.dev/sdk/telemetry/attributes/#units
public enum SentryMetricsUnit {
    // MARK: - Duration Units

    case nanosecond
    case microsecond
    case millisecond
    case second
    case minute
    case hour
    case day
    case week

    // MARK: - Information Units

    case bit
    case byte
    case kilobyte
    case kibibyte
    case megabyte
    case mebibyte
    case gigabyte
    case gibibyte
    case terabyte
    case tebibyte
    case petabyte
    case pebibyte
    case exabyte
    case exbibyte

    // MARK: - Fraction Units

    case ratio
    case percent

    // MARK: - Generic

    case generic(String)
}

extension SentryMetricsUnit: RawRepresentable {
    public typealias RawValue = String

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

extension SentryMetricsUnit: Equatable {
    public static func == (lhs: SentryMetricsUnit, rhs: SentryMetricsUnit) -> Bool {
        switch (lhs, rhs) {
        case (.nanosecond, .nanosecond),
             (.microsecond, .microsecond),
             (.millisecond, .millisecond),
             (.second, .second),
             (.minute, .minute),
             (.hour, .hour),
             (.day, .day),
             (.week, .week),
             (.bit, .bit),
             (.byte, .byte),
             (.kilobyte, .kilobyte),
             (.kibibyte, .kibibyte),
             (.megabyte, .megabyte),
             (.mebibyte, .mebibyte),
             (.gigabyte, .gigabyte),
             (.gibibyte, .gibibyte),
             (.terabyte, .terabyte),
             (.tebibyte, .tebibyte),
             (.petabyte, .petabyte),
             (.pebibyte, .pebibyte),
             (.exabyte, .exabyte),
             (.exbibyte, .exbibyte),
             (.ratio, .ratio),
             (.percent, .percent):
            return true
        case (.generic(let lhsValue), .generic(let rhsValue)):
            return lhsValue == rhsValue
        default:
            return false
        }
    }
}

extension SentryMetricsUnit: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension SentryMetricsUnit: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self = .generic(value)
    }
}
