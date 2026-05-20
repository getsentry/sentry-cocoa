#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 32-character hexadecimal identifier for a Sentry event.
@interface SentryCompatId : NSObject

/// Creates an id with a random UUID.
- (instancetype)init;

/// Creates an id from an existing UUID.
- (instancetype)initWithUuid:(NSUUID *)uuid;

/// Creates an id from a 32- or 36-character hex string. Falls back to `empty`
/// for invalid input.
- (instancetype)initWithUuidString:(NSString *)uuidString;

/// Lower-case 32-character hexadecimal string.
@property (nonatomic, readonly, copy) NSString *sentryIdString;

/// An id whose UUID is all zeros.
@property (class, nonatomic, readonly, strong) SentryCompatId *empty;

- (BOOL)isEqual:(nullable id)object;
@property (nonatomic, readonly) NSUInteger hash;
@property (nonatomic, readonly, copy) NSString *description;

@end

NS_ASSUME_NONNULL_END
