#import <Foundation/Foundation.h>

#import "SentryLogLevel.h"

#import "SentryAttribute.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

/**
 * A structured log entry.
 */
@interface SentryLog : NSObject

@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) SentryId *traceId;
@property (nonatomic, strong, nullable) SentrySpanId *spanId;
@property (nonatomic, assign) SentryLogLevel level;
@property (nonatomic, copy) NSString *body;
@property (nonatomic, copy) NSDictionary<NSString *, SentryAttribute *> *attributes;
@property (nonatomic, strong, nullable) NSNumber *severityNumber;

- (instancetype)initWithLevel:(SentryLogLevel)level body:(NSString *)body;
- (instancetype)initWithLevel:(SentryLogLevel)level
                         body:(NSString *)body
                   attributes:(NSDictionary<NSString *, SentryAttribute *> *)attributes;
- (void)setAttribute:(nullable SentryAttribute *)attribute forKey:(NSString *)key;

@end

NS_ASSUME_NONNULL_END
