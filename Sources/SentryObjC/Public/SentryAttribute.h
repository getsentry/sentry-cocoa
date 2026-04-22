#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// See SentryFeedback.h for an explanation of why SentryObjC's public headers alias
// the plain class name to the Swift-mangled class exported by Sentry.framework.
#if SWIFT_PACKAGE
@class _TtC11SentrySwift15SentryAttribute;
@compatibility_alias SentryAttribute _TtC11SentrySwift15SentryAttribute;
#else
@class _TtC6Sentry15SentryAttribute;
@compatibility_alias SentryAttribute _TtC6Sentry15SentryAttribute;
#endif

/**
 * A typed attribute value for structured logging and metrics.
 */
@interface SentryAttribute : NSObject

@property (nonatomic, readonly, copy) NSString *type;
@property (nonatomic, readonly, strong) id value;

- (instancetype)initWithString:(NSString *)value;
- (instancetype)initWithBoolean:(BOOL)value;
- (instancetype)initWithInteger:(NSInteger)value;
- (instancetype)initWithDouble:(double)value;

@end

NS_ASSUME_NONNULL_END
