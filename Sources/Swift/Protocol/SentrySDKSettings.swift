/**
 * Describes the settings for the Sentry SDK
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
final class SentrySDKSettings {
    
    init() {
        autoInferIP = false
    }
    
    convenience init(options: Options?) {
        self.init(sendDefaultPii: options?.sendDefaultPii ?? false)
    }

    init(sendDefaultPii: Bool) {
        autoInferIP = sendDefaultPii
    }
    
    init(dict: NSDictionary) {
        if let inferIp = dict["infer_ip"] as? String {
            autoInferIP = inferIp == "auto"
        } else {
            autoInferIP = false
        }
    }
    
    var autoInferIP: Bool
    
    func serialize() -> NSDictionary {
        [
            "infer_ip": autoInferIP ? "auto" : "never"
        ]
    }
}
