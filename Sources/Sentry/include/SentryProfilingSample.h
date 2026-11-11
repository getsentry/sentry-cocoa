#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Data associated with a single sample collected by the profiling engine. */
@interface SentryProfilingSample : NSObject

@property (nonatomic) uint64_t absoluteTimestamp;
@property (nonatomic) NSTimeInterval absoluteNSDateInterval;
@property (nonatomic, strong) NSNumber *stackIndex;
@property (nonatomic) uint64_t threadID;
@property (nonatomic, copy, nullable) NSString *queueAddress;

@end

NS_ASSUME_NONNULL_END
