#if SWIFT_PACKAGE
@_spi(Private) @testable import SentrySwift
#else
@_spi(Private) @testable import Sentry
#endif
import Foundation

@objc(SentryTestMetricsApi)
public final class TestMetricsApi: NSObject, SentryMetricsApiProtocol {

    @objc public let countInvocations = ObjCInvocations()
    @objc public let distributionInvocations = ObjCInvocations()
    @objc public let gaugeInvocations = ObjCInvocations()

    public func count(_ name: String, value: UInt, options: SentryMetricOptions) {
        countInvocations.record(Self.record(name: name, value: value, options: options))
    }

    public func distribution(_ name: String, value: Double, options: SentryMetricOptions) {
        distributionInvocations.record(Self.record(name: name, value: value, options: options))
    }

    public func gauge(_ name: String, value: Double, options: SentryMetricOptions) {
        gaugeInvocations.record(Self.record(name: name, value: value, options: options))
    }

    private static func record(name: String, value: Any, options: SentryMetricOptions) -> NSDictionary {
        var dict: [String: Any] = [
            "name": name,
            "value": value,
            "attributes": options.attributes.mapValues { $0.asSentryAttributeContent.anyValue }
        ]
        if let unit = options.unit {
            dict["unit"] = unit.rawValue
        }
        if let scope = options.scope {
            dict["scope"] = scope
        }
        if let timestamp = options.timestamp {
            dict["timestamp"] = timestamp
        }
        return dict as NSDictionary
    }
}
