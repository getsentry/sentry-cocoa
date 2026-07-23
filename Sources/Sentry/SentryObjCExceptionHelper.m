#import "SentryObjCExceptionHelper.h"

@implementation SentryObjCExceptionHelper

+ (BOOL)tryBlock:(NS_NOESCAPE void (^)(void))block
{
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        return NO;
    }
}

@end
