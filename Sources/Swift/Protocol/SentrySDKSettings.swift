/**
 * Describes the settings for the Sentry SDK
 * @see https://develop.sentry.dev/sdk/event-payloads/sdk/
 */
struct SentrySDKSettings {
    
    init() {
        autoInferIP = false
    }

    init(autoInferIP: Bool) {
        self.autoInferIP = autoInferIP
    }
    
    init(dict: NSDictionary) {
        if let inferIp = dict["infer_ip"] as? String {
            autoInferIP = inferIp == "auto"
        } else {
            autoInferIP = false
        }
    }
    
    let autoInferIP: Bool
    
    func serialize() -> NSDictionary {
        [
            "infer_ip": autoInferIP ? "auto" : "never"
        ]
    }
}
