#import "SentryDefines.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const SentryAppMemoryLevelChangedNotification;
FOUNDATION_EXPORT NSNotificationName const SentryAppMemoryPressureChangedNotification;
FOUNDATION_EXPORT NSString *const SentryAppMemoryNewValueKey;
FOUNDATION_EXPORT NSString *const SentryAppMemoryOldValueKey;

typedef NS_ENUM(NSUInteger, SentryAppMemoryLevel) {
    SentryAppMemoryLevelNormal = 0,
    SentryAppMemoryLevelWarn,
    SentryAppMemoryLevelUrgent,
    SentryAppMemoryLevelCritical,
    SentryAppMemoryLevelTerminal
};
FOUNDATION_EXPORT NSString *SentryAppMemoryLevelToString(SentryAppMemoryLevel level);
FOUNDATION_EXPORT SentryAppMemoryLevel SentryAppMemoryLevelFromString(NSString *const level);

typedef NS_ENUM(NSUInteger, SentryAppMemoryPressure) {
    SentryAppMemoryPressureNormal = 0,
    SentryAppMemoryPressureWarn,
    SentryAppMemoryPressureCritical,
};
FOUNDATION_EXPORT NSString *SentryAppMemoryPressureToString(SentryAppMemoryPressure pressure);
FOUNDATION_EXPORT SentryAppMemoryPressure SentryAppMemoryPressureFromString(NSString *const pressure);

@interface SentryAppMemory : NSObject <SentrySerializable>

+ (nullable instancetype)current;
- (nullable instancetype)initWithJSONObject:(NSDictionary *)jsonObject;

@property (readonly, nonatomic, assign) uint64_t footprint;
@property (readonly, nonatomic, assign) uint64_t remaining;
@property (readonly, nonatomic, assign) uint64_t limit;
@property (readonly, nonatomic, assign) SentryAppMemoryLevel level;
@property (readonly, nonatomic, assign) SentryAppMemoryPressure pressure;

- (BOOL)isLikelyOutOfMemory;

@end

// Internal and for tests.
@interface SentryAppMemory ()
- (instancetype)initWithFootprint:(uint64_t)footprint remaining:(uint64_t)remaining pressure:(SentryAppMemoryPressure)pressure;
@end

NS_ASSUME_NONNULL_END
