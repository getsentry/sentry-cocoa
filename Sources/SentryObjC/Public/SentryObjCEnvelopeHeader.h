#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCTraceContext;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCEnvelopeHeader : NSObject

@property (nonatomic, readonly, strong, nullable) SentryObjCId *eventId;
@property (nonatomic, readonly, strong, nullable) SentryObjCTraceContext *traceContext;
@property (nonatomic, strong, nullable) NSDate *sentAt;

- (instancetype)initWithId:(nullable SentryObjCId *)eventId;
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
              traceContext:(nullable SentryObjCTraceContext *)traceContext;
+ (instancetype)empty;

@end

NS_ASSUME_NONNULL_END
