import Foundation
@_spi(Private) @testable import Sentry

@objc(SentryTestMetricsApi)
public final class TestMetricsApi: NSObject, SentryMetricsApiProtocol {

    @objc public let countInvocations = ObjCInvocations()
    @objc public let distributionInvocations = ObjCInvocations()
    @objc public let gaugeInvocations = ObjCInvocations()

    public func count(key: String, value: UInt, attributes: [String: SentryAttributeValue]) {
        countInvocations.record(["key": key, "value": value] as NSDictionary)
    }

    public func distribution(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        var dict: [String: Any] = ["key": key, "value": value]
        if let unit {
            dict["unit"] = unit.rawValue
        }
        distributionInvocations.record(dict as NSDictionary)
    }

    public func gauge(key: String, value: Double, unit: SentryUnit?, attributes: [String: SentryAttributeValue]) {
        var dict: [String: Any] = ["key": key, "value": value]
        if let unit {
            dict["unit"] = unit.rawValue
        }
        gaugeInvocations.record(dict as NSDictionary)
    }
}
