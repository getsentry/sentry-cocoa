#import "SentryEvent.h"
#import <Foundation/Foundation.h>

@interface
SentryEvent (Private)

/**
 * This indicates whether this event is a result of a crash.
 */
@property (nonatomic) BOOL isCrashEvent;
@property (nonatomic, strong) NSArray *serializedBreadcrumbs;

@property (nonatomic) uint64_t startSystemTime;
@property (nonatomic) uint64_t endSystemTime;

@end
