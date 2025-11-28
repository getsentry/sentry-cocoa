/**
 * Describes the settings for the Sentry SDK
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
@_spi(Private) @objc public final class SentrySDKSettings: NSObject, Codable {

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.autoInferIP = (try? container.decode(String.self, forKey: .autoInferIP) == "auto") ?? false
    }
    
    enum CodingKeys: String, CodingKey {
        case autoInferIP = "inferIp"
    }
    
    @objc public override init() {
        autoInferIP = false
    }
    
    @objc public convenience init(options: Options?) {
        self.init(sendDefaultPii: options?.sendDefaultPii ?? false)
    }

    @objc public init(sendDefaultPii: Bool) {
        autoInferIP = sendDefaultPii
    }
    
    @objc public var autoInferIP: Bool
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.autoInferIP ? "auto" : "never", forKey: .autoInferIP)
    }
}
