#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Parsed representation of a Sentry DSN.
@interface SentryCompatDsn : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithString:(nullable NSString *)dsnString
                       didFailWithError:(NSError *_Nullable *_Nullable)error;

@property (nonatomic, readonly, copy) NSURL *url;

- (NSURL *)getEnvelopeEndpoint;

@end

NS_ASSUME_NONNULL_END
