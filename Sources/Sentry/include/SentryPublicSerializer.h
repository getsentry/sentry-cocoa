#import <Foundation/Foundation.h>

@class SentryUser;
@class SentryEvent;
@class SentryTraceContext;
@class SentryEnvelopeItemHeader;

NS_ASSUME_NONNULL_BEGIN

@interface SentryPublicSerializer: NSObject

+ (NSDictionary<NSString *, id> *)serializeUser:(SentryUser *)user;

+ (NSDictionary<NSString *, id> *)serializeTraceContext:(SentryTraceContext *)traceContext;

+ (NSDictionary<NSString *, id> *)serializeEnvelopeHeader:(SentryEnvelopeItemHeader *)header;

+ (NSDictionary<NSString *, id> *)serializeEvent:(SentryEvent *)event;

@end

NS_ASSUME_NONNULL_END
