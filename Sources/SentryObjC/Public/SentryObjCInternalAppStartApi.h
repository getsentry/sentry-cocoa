#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// App start APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalAppStartApi : NSObject

/// When enabled, the SDK won't send the app start measurement with the first transaction.
@property (nonatomic, assign) BOOL hybridSDKMode;

/// The app start measurement serialized as a dictionary with span data.
@property (nonatomic, readonly, nullable, copy) NSDictionary<NSString *, id> *measurementWithSpans;

@end

NS_ASSUME_NONNULL_END
