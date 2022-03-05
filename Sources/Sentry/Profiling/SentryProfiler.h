#import <Foundation/Foundation.h>

@interface SentryProfiler : NSObject

/**
 * Returns a copy of the currently accumulated profile data. This
 * data will be cleared each time -start is called.
 */
@property (nonatomic, copy, readonly) NSDictionary *profile;

- (void)start;
- (void)stop;

@end
