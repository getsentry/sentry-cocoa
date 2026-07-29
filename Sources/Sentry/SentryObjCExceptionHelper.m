#import "SentryObjCExceptionHelper.h"
#import "SentryLogC.h"

@implementation SentryObjCExceptionHelper

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block
{
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        SENTRY_LOG_WARN(@"Caught Objective-C exception %@: %@", exception.name, exception.reason);
        return NO;
    }
}

@end
