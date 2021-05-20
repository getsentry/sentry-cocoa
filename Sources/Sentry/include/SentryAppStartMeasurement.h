#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

static NSString *const SentryAppStartTypeWarm = @"warm";
static NSString *const SentryAppStartTypeCold = @"cold";
static NSString *const SentryAppStartTypeUnkown = @"unknown";

@interface SentryAppStartMeasurement : NSObject
SENTRY_NO_INIT

/**
 * Initializes SentryAppStartMeasurement with the given parameters.
 *
 * @param type The type of the app start. Either cold or warm.
 * @param duration The duration of the app start.
 */
- (instancetype)initWithType:(NSString *)type duration:(NSTimeInterval)duration;

/**
 * The type of the app start. Either cold or warm.
 */
@property (readonly, nonatomic, copy) NSString *type;

/**
 * How long the app start toock.
 */
@property (readonly, nonatomic, assign) NSTimeInterval duration;

@end

NS_ASSUME_NONNULL_END
