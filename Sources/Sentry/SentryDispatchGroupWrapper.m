#import <Foundation/Foundation.h>
#import <SentryDispatchGroupWrapper.h>

NS_ASSUME_NONNULL_BEGIN

@implementation SentryDispatchGroupWrapper {
    dispatch_group_t dispatchGroup;
}

- (instancetype)init
{
    if (self = [super init]) {
        dispatchGroup = dispatch_group_create();
    }
    return self;
}

- (intptr_t)waitWithTimeout:(dispatch_time_t)timeout
{
    return dispatch_group_wait(dispatchGroup, timeout);
}

- (void)enter
{
    dispatch_group_enter(dispatchGroup);
}

- (void)leave
{
    dispatch_group_leave(dispatchGroup);
}

@end

NS_ASSUME_NONNULL_END
