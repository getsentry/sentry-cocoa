#import "SentryDefines.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(HttpStatusCodeRange)
@interface SentryHttpStatusCodeRange : NSObject

@property (nonatomic) NSInteger min;

@property (nonatomic) NSInteger max;

- (instancetype)initWithMin:(NSInteger)min andMax:(NSInteger)max;

- (instancetype)initWithStatusCode:(NSInteger)statusCode;

- (BOOL)isInRange:(NSInteger)statusCode;

@end

NS_ASSUME_NONNULL_END
