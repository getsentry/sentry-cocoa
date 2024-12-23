@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryRRWebOptionsEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, options: SentryReplayOptions) {
        super.init(timestamp: timestamp, tag: "options", payload:
                    [
                        "sessionSampleRate": options.sessionSampleRate,
                        "errorSampleRate": options.onErrorSampleRate,
                        "maskAllText": options.maskAllText,
                        "maskAllImages": options.maskAllImages,
                        "quality": String(describing: options.quality),
                        "maskedViewClasses": options.maskedViewClasses.map(String.init(describing: )).joined(separator: ", "),
                        "unmaskedViewClasses": options.unmaskedViewClasses.map(String.init(describing: )).joined(separator: ", "),
                        "nativeSdkName": SentryMeta.nativeSdkName,
                        "nativeSdkVersion": SentryMeta.nativeVersionString,
                    ]
        )
    }
}
