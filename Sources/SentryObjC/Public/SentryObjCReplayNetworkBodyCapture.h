#if SDK_V10
#    import <Foundation/Foundation.h>

/// Controls whether Session Replay captures HTTP request and response bodies.
typedef NS_ENUM(NSInteger, SentryObjCReplayNetworkBodyCapture) {
    /// Inherit request and response body capture from data collection options.
    SentryObjCReplayNetworkBodyCaptureInherit = 0,
    /// Capture both request and response bodies.
    SentryObjCReplayNetworkBodyCaptureEnabled,
    /// Do not capture request or response bodies.
    SentryObjCReplayNetworkBodyCaptureDisabled
};
#endif // SDK_V10
