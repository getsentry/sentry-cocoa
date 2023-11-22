#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn : SENTRY_BASE_OBJECT

@property (nonatomic, strong, readonly) NSURL *url;

- (_Nullable instancetype)initWithString:(NSString *)dsnString
                        didFailWithError:(NSError *_Nullable *_Nullable)error;

- (NSString *)getHash;

- (NSURL *)getStoreEndpoint;
- (NSURL *)getEnvelopeEndpoint;

@end

NS_ASSUME_NONNULL_END
