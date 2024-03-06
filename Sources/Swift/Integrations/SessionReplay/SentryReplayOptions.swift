import Foundation




@objcMembers
public class SentryReplayOptions : NSObject {
    /**
     * Indicates the percentage in which the replay for the session will be created.
     * @discussion Specifying @c 0 means never, @c 1.0 means always.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * @note The default is @c 0.
     */
    public let replaysSessionSampleRate: Float

    /**
     * Indicates the percentage in which a 30 seconds replay will be send with error events.
     * @discussion Specifying @c 0 means never, @c 1.0 means always.
     * @note The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * @note The default is @c 0.
     */
    public let replaysOnErrorSampleRate: Float

    /**
     * Defines the quality of the session replay.
     * Higher bit rates better quality, but also bigger files to transfer.
     * @note The default value is @c 20000;
     */
    let replayBitRate = 20000;
    
    /**
     * Inittialize session replay options disabled
     */
    public override init() {
        self.replaysSessionSampleRate = 0
        self.replaysOnErrorSampleRate = 0
    }
    
    /**
     * Inittialize session replay options
     *
     *  sessionSampleRate Indicates the percentage in which the replay for the session will be
     * created.
     * @param errorSampleRate Indicates the percentage in which a 30 seconds replay will be send with
     * error events.
     */
    public init(sessionSampleRate: Float, errorSampleRate: Float) {
        self.replaysSessionSampleRate = sessionSampleRate
        self.replaysOnErrorSampleRate = errorSampleRate
    }
    
    convenience init(dictionary: NSDictionary) {
        let sessionSampleRate = (dictionary["replaysSessionSampleRate"] as? NSNumber)?.floatValue ?? 0
        let onErrorSampleRate = (dictionary["replaysOnErrorSampleRate"] as? NSNumber)?.floatValue ?? 0
        self.init(sessionSampleRate: sessionSampleRate, errorSampleRate: onErrorSampleRate)
    }
}
