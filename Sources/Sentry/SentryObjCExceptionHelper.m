#import "SentryObjCExceptionHelper.h"
#import "SentryLogC.h"

@implementation SentryObjCExceptionHelper

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block
    catchingExceptionWithName:(NSExceptionName)name
                 reasonPrefix:(NSString *)reasonPrefix
{
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (![exception.name isEqualToString:name] || ![exception.reason hasPrefix:reasonPrefix]) {
            @throw;
        }

        SENTRY_LOG_WARN(@"Caught Objective-C exception %@: %@", exception.name, exception.reason);
        return NO;
    }
}

@end
