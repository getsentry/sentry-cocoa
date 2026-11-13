#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** An immutable, UUID-backed identifier owned by the profiling engine. */
@interface SentryProfilingId : NSObject <NSCopying>

@property (nonatomic, strong, readonly) NSUUID *uuid;

/** UUID formatted as 32 lowercase hexadecimal characters for the profile wire format. */
@property (nonatomic, copy, readonly) NSString *stringValue;

- (instancetype)init;
- (instancetype)initWithUUID:(NSUUID *)uuid NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
