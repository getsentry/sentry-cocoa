#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#import "SentryObjCDefines.h"
#import "SentryReplayOptions.h"

#if SENTRY_OBJC_REPLAY_SUPPORTED

static const void *kNetworkDetailAllowUrlsKey = &kNetworkDetailAllowUrlsKey;
static const void *kNetworkDetailDenyUrlsKey = &kNetworkDetailDenyUrlsKey;

@implementation SentryReplayOptions (ObjCBridge)

- (void)setNetworkDetailAllowUrls:(NSArray *)urls
{
    objc_setAssociatedObject(self, kNetworkDetailAllowUrlsKey, urls, OBJC_ASSOCIATION_COPY);
}

- (NSArray *)networkDetailAllowUrls
{
    return objc_getAssociatedObject(self, kNetworkDetailAllowUrlsKey) ?: @[];
}

- (void)setNetworkDetailDenyUrls:(NSArray *)urls
{
    objc_setAssociatedObject(self, kNetworkDetailDenyUrlsKey, urls, OBJC_ASSOCIATION_COPY);
}

- (NSArray *)networkDetailDenyUrls
{
    return objc_getAssociatedObject(self, kNetworkDetailDenyUrlsKey) ?: @[];
}

@end

#endif // SENTRY_OBJC_REPLAY_SUPPORTED
