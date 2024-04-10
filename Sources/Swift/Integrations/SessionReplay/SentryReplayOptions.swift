import Foundation

@objcMembers
public class SentryReplayOptions: NSObject, SentryRedactOptions {
    /**
     * Indicates the percentage in which the replay for the session will be created.
     * - Specifying @c 0 means never, @c 1.0 means always.
     * - note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - note:  The default is 0.
     */
    public var sessionSampleRate: Float

    /**
     * Indicates the percentage in which a 30 seconds replay will be send with error events.
     * - Specifying 0 means never, 1.0 means always.
     * - note: The value needs to be >= 0.0 and \<= 1.0. When setting a value out of range the SDK sets it
     * to the default.
     * - note: The default is 0.
     */
    public var errorSampleRate: Float
    
    /**
     * Indicates whether session replay should redact all text in the app
     * by drawing a black rectangle over it.
     *
     * - note: The default is true
     */
    public var redactAllText = true
    
    /**
     * Indicates whether session replay should redact all non-bundled image
     * in the app by drawing a black rectangle over it.
     *
     * - note: The default is true
     */
    public var redactAllImages = true
    
    /**
     * Defines the quality of the session replay.
     * Higher bit rates better quality, but also bigger files to transfer.
     * @note The default value is @c 20000;
     */
    let replayBitRate = 20_000
    
    /**
     * Number of frames per second of the replay.
     * The more the havier the process is.
     */
    let frameRate = 1
    
    /**
     * The scale related to the window size at which the replay will be created
     */
    let sizeScale = 0.8
   
    /**
     * The maximum duration of replays for error events.
     */
    let errorReplayDuration = TimeInterval(30)
    
    /**
     * The maximum duration of the segment of a session replay.
     */
    let sessionSegmentDuration = TimeInterval(5)
    
    /**
     * The maximum duration of a replay session.
     */
    let maximumDuration = TimeInterval(3_600)
    
    /**
     * Inittialize session replay options disabled
     */
    public override init() {
        self.sessionSampleRate = 0
        self.errorSampleRate = 0
    }
    
    /**
     * Initialize session replay options
     * - parameters:
     *  - sessionSampleRate Indicates the percentage in which the replay for the session will be created.
     *  - errorSampleRate Indicates the percentage in which a 30 seconds replay will be send with
     * error events.
     */
    public init(sessionSampleRate: Float = 0, errorSampleRate: Float = 0, redactAllText: Bool = true, redactAllImages: Bool = true) {
        self.sessionSampleRate = sessionSampleRate
        self.errorSampleRate = errorSampleRate
        self.redactAllText = redactAllText
        self.redactAllImages = redactAllImages
    }
    
    convenience init(dictionary: [String: Any]) {
        let sessionSampleRate = (dictionary["sessionSampleRate"] as? NSNumber)?.floatValue ?? 0
        let onErrorSampleRate = (dictionary["errorSampleRate"] as? NSNumber)?.floatValue ?? 0
        let redactAllText = (dictionary["redactAllText"] as? NSNumber)?.boolValue ?? true
        let redactAllImages = (dictionary["redactAllImages"] as? NSNumber)?.boolValue ?? true
        self.init(sessionSampleRate: sessionSampleRate, errorSampleRate: onErrorSampleRate, redactAllText: redactAllText, redactAllImages: redactAllImages)
    }
}
