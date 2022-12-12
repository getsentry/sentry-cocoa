#import "SentryDefines.h"
#import "SentryEvent.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, SentryEventOptions) {
    kSentryEventOptionsNone = 0,
    kSentryEventOptionsAddNoScreenshots = 1 << 0,
    kSentryEventOptionsAddNoViewHierarchy = 1 << 1,
};

@interface
SentryEvent (Private)

@property (nonatomic) SentryEventOptions eventOptions;

@property (nonatomic, strong) NSArray *serializedBreadcrumbs;

@end

NS_ASSUME_NONNULL_END
