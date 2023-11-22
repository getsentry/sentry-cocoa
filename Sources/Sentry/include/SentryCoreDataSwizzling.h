#import "SentryDefines.h"
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryCoreDataTracker;

@interface SentryCoreDataSwizzling : SENTRY_BASE_OBJECT
SENTRY_NO_INIT

@property (class, readonly, nonatomic) SentryCoreDataSwizzling *sharedInstance;

@property (nonatomic, readonly, nullable) SentryCoreDataTracker *coreDataTracker;

- (void)startWithTracker:(SentryCoreDataTracker *)coreDataTracker;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
