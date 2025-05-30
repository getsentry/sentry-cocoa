#import "ExceptionCatcher.h"

@implementation ExceptionCatcher

+ (NSException *)tryBlock:(void (^)(void))tryBlock
{
    @try {
        tryBlock();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}

@end
