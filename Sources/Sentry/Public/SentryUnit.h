#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryUnit : NSObject <NSCopying>
SENTRY_NO_INIT

- (instancetype)initWithSymbol:(NSString *)symbol;

@property (readonly, copy) NSString *symbol;

@end

@interface SentryUnitDuration : SentryUnit
SENTRY_NO_INIT

/** Nanosecond (`"nanosecond"`), 10^-9 seconds. */
@property (class, readonly, copy) SentryUnitDuration *nanoseconds;

// ...

@end

@interface SentryUnitInformation : SentryUnit
SENTRY_NO_INIT

/** Bit (`"bit"`), corresponding to 1/8 of a byte. */
@property (class, readonly, copy) SentryUnitInformation *bit;

// ...

@end

@interface SentryUnitFraction : SentryUnit
SENTRY_NO_INIT

/** Floating point fraction of `1`. */
@property (class, readonly, copy) SentryUnitFraction *ratio;

/** Ratio expressed as a fraction of `100`. `100%` equals a ratio of `1.0`. */
@property (class, readonly, copy) SentryUnitFraction *percent;

// ...

@end

NS_ASSUME_NONNULL_END
