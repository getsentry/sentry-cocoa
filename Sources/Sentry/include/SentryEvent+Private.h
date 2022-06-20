#import <Foundation/Foundation.h>
#import "SentryEvent.h"

@interface SentryEvent (Private)

/**
 * This indicates whether this event is a result of a crash.
 */
@property (nonatomic) BOOL isCrashEvent;

@end
