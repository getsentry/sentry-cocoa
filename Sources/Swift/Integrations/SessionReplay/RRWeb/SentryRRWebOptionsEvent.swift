internal import _SentryPrivate
import Foundation

final class SentryRRWebOptionsEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, customOptions: [String: Any]) {
        super.init(timestamp: timestamp, tag: "options", payload: customOptions)
    }
    
    init(timestamp: Date, options: SentryReplayOptions, redactOptions: SentryRedactOptions) {
        var payload: [String: Any] = [
            "sessionSampleRate": options.sessionSampleRate,
            "errorSampleRate": options.onErrorSampleRate,
            "maskAllText": redactOptions.maskAllText,
            "maskAllImages": redactOptions.maskAllImages,
            "quality": String(describing: options.quality),
            "nativeSdkName": SentryMeta.sdkName,
            "nativeSdkVersion": SentryMeta.versionString
        ]
        
        if !redactOptions.maskedViewClasses.isEmpty {
            payload["maskedViewClasses"] = redactOptions.maskedViewClasses.map(String.init(describing:)).joined(separator: ", ")
        }
        
        if !redactOptions.unmaskedViewClasses.isEmpty {
            payload["unmaskedViewClasses"] = redactOptions.unmaskedViewClasses.map(String.init(describing:)).joined(separator: ", ")
        }
        
        payload["networkDetailHasUrls"] = options.networkDetailHasUrls

        if options.networkDetailHasUrls {
            payload["networkDetailAllowUrls"] = options.networkDetailAllowUrls.map { pattern in
                if let regex = pattern as? NSRegularExpression {
                    return regex.pattern
                } else {
                    return String(describing: pattern)
                }
            }
            payload["networkDetailDenyUrls"] = options.networkDetailDenyUrls.map { pattern in
                if let regex = pattern as? NSRegularExpression {
                    return regex.pattern
                } else {
                    return String(describing: pattern)
                }
            }
            payload["networkCaptureBodies"] = options.networkCaptureBodies
            payload["networkRequestHeaders"] = options.networkRequestHeaders
            payload["networkResponseHeaders"] = options.networkResponseHeaders
        }

        super.init(timestamp: timestamp, tag: "options", payload: payload)
    }
}
