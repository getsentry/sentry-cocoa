#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

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
