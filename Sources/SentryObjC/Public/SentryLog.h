#import <Foundation/Foundation.h>

#import "SentryLogLevel.h"

// SentryAttribute is Swift-backed and uses @compatibility_alias in its header; importing
// the full header avoids a "conflicting types for alias" error if SentryAttribute.h is
// later included in the same TU after a plain forward declaration here.
#import "SentryAttribute.h"

@class SentryId;
@class SentrySpanId;

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift9SentryLog;
@compatibility_alias SentryLog _TtC11SentrySwift9SentryLog;
#else
@class _TtC6Sentry9SentryLog;
@compatibility_alias SentryLog _TtC6Sentry9SentryLog;
#endif

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
