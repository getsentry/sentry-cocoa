#import "RaiseUncaughtNSException.h"

void
RaiseUncaughtNSException(NSString *name, NSString *reason)
{
    // Copied from CrashE2ETriggerRethrownNSException: a bare @throw in an
    // Objective-C catch lowers to objc_exception_rethrow, which is the path
    // SentryCrash's NSException monitor actually records.
    @try {
        [[NSException exceptionWithName:name reason:reason userInfo:nil] raise];
    } @catch (__unused NSException *exception) {
        @throw;
    }
}
