#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDsn : NSObject

@property (nonatomic, strong, readonly) NSURL *url;

- (_Nullable instancetype)initWithString:(NSString *_Nullable)dsnString
                        didFailWithError:(NSError *_Nullable *_Nullable)error;

- (NSURL *)getEnvelopeEndpoint;

@end

NS_ASSUME_NONNULL_END
