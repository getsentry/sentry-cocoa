#import "SentryNSExceptionHandler.h"

NSString *const SentryNSExceptionErrorDomain = @"SentryNSException";

id _Nullable SentryTryCatch(
    id _Nullable(NS_NOESCAPE ^ block)(void), NSError *_Nullable *_Nullable error)
{
    @try {
        return block();
    } @catch (NSException *exception) {
        if (error != nil) {
            *error =
                [NSError errorWithDomain:SentryNSExceptionErrorDomain
                                    code:0
                                userInfo:@ { NSLocalizedDescriptionKey : exception.description }];
        }
        return nil;
    }
}
