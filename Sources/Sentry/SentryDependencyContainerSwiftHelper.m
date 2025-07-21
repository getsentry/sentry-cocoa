#import "SentryDependencyContainerSwiftHelper.h"
#import "SentryDependencyContainer.h"
#import "SentryHub+Private.h"
#import "SentrySDK+Private.h"
#import "SentrySDKInternal.h"
#import "SentrySwift.h"
#import "SentryUIApplication.h"
#import "SentryUserFeedbackIntegration.h"

@interface SentryCurrentDateProviderSwift : NSObject <SentryInternalCurrentDateProvider>

- (instancetype)initWithDateProvider:(id<SentryCurrentDateProvider>)dateProvider;

@property (strong, nonatomic) id<SentryCurrentDateProvider> dateProvider;

@end

@implementation SentryCurrentDateProviderSwift

- (instancetype)initWithDateProvider:(id<SentryCurrentDateProvider>)dateProvider
{
    self = [super init];
    if (self) {
        self.dateProvider = dateProvider;
    }
    return self;
}

- (nonnull NSDate *)date
{
    return self.dateProvider.date;
}

- (uint64_t)systemTime
{
    return self.dateProvider.systemTime;
}

- (NSTimeInterval)systemUptime
{
    return self.dateProvider.systemUptime;
}

- (NSInteger)timezoneOffset
{
    return self.dateProvider.timezoneOffset;
}

@end

@implementation SentrySwiftHelpers

#if SENTRY_HAS_UIKIT

+ (NSArray<UIWindow *> *)windows
{
    return SentryDependencyContainer.sharedInstance.application.windows;
}

#endif // SENTRY_HAS_UIKIT

+ (void)dispatchSyncOnMainQueue:(void (^)(void))block
{
    [SentryDependencyContainer.sharedInstance.dispatchQueueWrapper dispatchSyncOnMainQueue:block];
}

+ (id<SentryInternalCurrentDateProvider>)currentDateProvider
{
    return [[SentryCurrentDateProviderSwift alloc]
        initWithDateProvider:SentryDependencyContainer.sharedInstance.dateProvider];
}

+ (SentryHub *)currentHub
{
    return SentrySDKInternal.currentHub;
}

+ (id<SentryObjCRuntimeWrapper>)objcRuntimeWrapper
{
    return SentryDependencyContainer.sharedInstance.objcRuntimeWrapper;
}

@end
