#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(HttpStatusCodeRange)
@interface SentryHttpStatusCodeRange : NSObject

@property (nonatomic, copy) NSNumber *min;

@property (nonatomic, copy) NSNumber *max;

- (instancetype)initWithMin:(NSNumber *)min andMax:(NSNumber *)max;

- (instancetype)initWithStatusCode:(NSNumber *)statusCode;

- (BOOL)isInRange:(NSNumber *)statusCode;

@end

NS_ASSUME_NONNULL_END
