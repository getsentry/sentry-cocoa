#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 16-character span identifier.
@interface SOCSentrySpanId : NSObject

/// Creates a span id with a random 16-character value.
- (instancetype)init;

/// Creates a span id from the first 16 characters of a UUID.
- (instancetype)initWithUuid:(NSUUID *)uuid;

/// Creates a span id from a 16-character string. Falls back to `empty` for
/// invalid input.
- (instancetype)initWithValue:(NSString *)value;

@property (nonatomic, readonly, copy) NSString *sentrySpanIdString;

@property (class, nonatomic, readonly, strong) SOCSentrySpanId *empty;

- (BOOL)isEqual:(nullable id)object;
@property (nonatomic, readonly) NSUInteger hash;
@property (nonatomic, readonly, copy) NSString *description;

@end

NS_ASSUME_NONNULL_END
