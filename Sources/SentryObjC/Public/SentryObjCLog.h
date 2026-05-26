#import "SentryObjCLogLevel.h"
#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCSpanId;
@class SentryObjCAttribute;

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCLog : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) SentryObjCId *traceId;
@property (nonatomic, strong, nullable) SentryObjCSpanId *spanId;
@property (nonatomic) SentryObjCLogLevel level;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSDictionary<NSString *, SentryObjCAttribute *> *attributes;
@property (nonatomic, strong, nullable) NSNumber *severityNumber;

- (instancetype)initWithLevel:(SentryObjCLogLevel)level body:(NSString *)body;
- (instancetype)initWithLevel:(SentryObjCLogLevel)level
                         body:(NSString *)body
                   attributes:(NSDictionary<NSString *, SentryObjCAttribute *> *)attributes;

- (void)setAttribute:(nullable SentryObjCAttribute *)attribute forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
