@_implementationOnly import _SentryPrivate
import Foundation

@objc class SentryRRWebOptionsEvent: SentryRRWebCustomEvent {
    
    init(timestamp: Date, options: SentryReplayOptions) {
        super.init(timestamp: timestamp, tag: "options", payload:
                    [
                        "sessionSampleRate": options.sessionSampleRate,
                        "errorSampleRate": options.onErrorSampleRate,
                        "maskAllText": options.maskAllText,
                        "maskAllImates": options.maskAllImages,
                        "maskedViewClasses": options.maskedViewClasses.map(String.init(describing: )),
                        "unmaskedViewClasses": options.unmaskedViewClasses.map(String.init(describing: ))
                    ]
        )
    }
}
