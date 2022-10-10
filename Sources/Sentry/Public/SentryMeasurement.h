#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentryUnit.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryMeasurement<UnitType : SentryUnit *> : NSObject <SentrySerializable>
SENTRY_NO_INIT

- (instancetype)initWithName:(NSString *)name value:(NSNumber *)value unit:(UnitType)unit;

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, copy, readonly) NSNumber *value;
@property (readonly, copy) UnitType unit;

@end

NS_ASSUME_NONNULL_END
