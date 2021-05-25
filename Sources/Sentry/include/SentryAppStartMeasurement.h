#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SentryAppStartType) {
    SentryAppStartTypeWarm,
    SentryAppStartTypeCold,
    SentryAppStartTypeUnknown,
};

@interface SentryAppStartMeasurement : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryAppStartMeasurement with the given parameters.
 *
 * @param type The type of the app start. Either cold or warm.
 * @param duration The duration of the app start.
 */
- (instancetype)initWithType:(SentryAppStartType)type duration:(NSTimeInterval)duration;

/**
 * The type of the app start. Either cold or warm.
 */
@property (readonly, nonatomic, assign) SentryAppStartType type;

/**
 * How long the app start toock.
 */
@property (readonly, nonatomic, assign) NSTimeInterval duration;

@end

NS_ASSUME_NONNULL_END
