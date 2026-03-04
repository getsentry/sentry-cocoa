#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryMechanism;
@class SentryStacktrace;

NS_ASSUME_NONNULL_BEGIN

/**
 * Exception information for an event.
 *
 * @see SentryEvent
 */
@interface SentryException : NSObject <SentrySerializable>

SENTRY_NO_INIT

@property (nonatomic, copy) NSString *value;
@property (nonatomic, copy) NSString *type;
@property (nonatomic, strong) SentryMechanism *mechanism;
@property (nonatomic, copy) NSString *module;
@property (nonatomic, copy) NSNumber *threadId;
@property (nonatomic, strong) SentryStacktrace *stacktrace;

- (instancetype)initWithValue:(NSString *)value type:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
