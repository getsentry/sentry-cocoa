#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Thread information for an event.
 *
 * @see SentryEvent
 */
@interface SentryThread : NSObject <SentrySerializable>

SENTRY_NO_INIT

@property (nullable, nonatomic, copy) NSNumber *threadId;
@property (nullable, nonatomic, copy) NSString *name;
@property (nullable, nonatomic, strong) SentryStacktrace *stacktrace;
@property (nullable, nonatomic, copy) NSNumber *crashed;
@property (nullable, nonatomic, copy) NSNumber *current;
@property (nullable, nonatomic, copy) NSNumber *isMain;

- (instancetype)initWithThreadId:(nullable NSNumber *)threadId;

@end

NS_ASSUME_NONNULL_END
