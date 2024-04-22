#import "SentryMemoryEventBreadcrumbs.h"
#import "SentryBreadcrumb.h"
#import "SentryBreadcrumbDelegate.h"
#import "SentryDefines.h"
#import "SentryDependencyContainer.h"
#import "SentryLog.h"
#import "SentryAppMemory.h"

#if TARGET_OS_IOS && SENTRY_HAS_UIKIT

@interface
SentryMemoryEventBreadcrumbs ()
@property (nonatomic, weak) id<SentryBreadcrumbDelegate> delegate;
@end

@implementation SentryMemoryEventBreadcrumbs

- (void)stop
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:SentryAppMemoryPressureChangedNotification
                                                  object:nil];
}

- (void)dealloc
{
    [self stop];
}

- (void)startWithDelegate:(id<SentryBreadcrumbDelegate>)delegate
{
    [self stop];
    
    _delegate = delegate;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_memoryChanged) 
                                                 name:SentryAppMemoryPressureChangedNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_memoryChanged) 
                                                 name:SentryAppMemoryLevelChangedNotification
                                               object:nil];
    
    [self _memoryChanged];
}

- (void)_memoryChanged
{
    SentryBreadcrumb *crumb = [[SentryBreadcrumb alloc] initWithLevel:kSentryLevelInfo
                                                             category:@"memory.event"];
    crumb.type = @"memory";
    crumb.data = [SentryAppMemory current].serialize;
    [_delegate addBreadcrumb:crumb];
}

@end

#endif // TARGET_OS_IOS && SENTRY_HAS_UIKIT
