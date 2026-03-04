#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"
#import "SentryObjCSerializable.h"

@class SentryFrame;

NS_ASSUME_NONNULL_BEGIN

/**
 * Stack trace containing frames.
 *
 * @see SentryEvent
 * @see SentryException
 */
@interface SentryStacktrace : NSObject <SentrySerializable>

SENTRY_NO_INIT

@property (nonatomic, strong) NSArray<SentryFrame *> *frames;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *registers;
@property (nonatomic, copy, nullable) NSNumber *snapshot;

- (instancetype)initWithFrames:(NSArray<SentryFrame *> *)frames
                     registers:(NSDictionary<NSString *, NSString *> *)registers;
- (void)fixDuplicateFrames;

@end

NS_ASSUME_NONNULL_END
