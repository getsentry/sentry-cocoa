#import "SentryDefines.h"
#import "SentryMeasurementUnit.h"
#import "SentrySerializable.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryMeasurement : NSObject
SENTRY_NO_INIT

- (instancetype)initWithName:(NSString *)name value:(NSNumber *)value;

- (instancetype)initWithName:(NSString *)name
                       value:(NSNumber *)value
                        unit:(SentryMeasurementUnit *)unit;

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSNumber *value;
@property (nullable, readonly, copy) SentryMeasurementUnit *unit;

@end

NS_ASSUME_NONNULL_END
