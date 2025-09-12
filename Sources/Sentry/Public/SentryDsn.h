#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn : NSObject

@property (nonatomic, strong, readonly) NSURL *url;

- (_Nullable instancetype)initWithString:(NSString *)dsnString
                        didFailWithError:(NSError *_Nullable *_Nullable)error;

#if !SDK_V9
- (NSString *)getHash;
- (NSURL *)getStoreEndpoint DEPRECATED_MSG_ATTRIBUTE("This endpoint is no longer used");
#endif // !SDK_V9
- (NSURL *)getEnvelopeEndpoint;

@end

NS_ASSUME_NONNULL_END
