#import <Foundation/Foundation.h>

@interface SentryANRStoppedResultInternal : NSObject

@property (nonatomic, readonly) NSTimeInterval minDuration;

@property (nonatomic, readonly) NSTimeInterval maxDuration;

- (instancetype)initWithMinDuration:(NSTimeInterval)minDuration
                        maxDuration:(NSTimeInterval)maxDuration;

@end
