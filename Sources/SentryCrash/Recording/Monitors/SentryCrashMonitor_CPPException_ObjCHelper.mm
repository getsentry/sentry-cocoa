#import "SentryCrashMonitor_CPPException_ObjCHelper.h"
#import "SentryCrashStackCursor_Backtrace.h"
#import "SentryCrashStackCursor_SelfThread.h"

#import "SentryLogC.h"

#import <Foundation/Foundation.h>
#include <exception>

uintptr_t *
sentrycrashcm_extractCurrentObjCException(
    const char **outName, const char **outReason, SentryCrashStackCursor *outCursor)
{
    *outName = NULL;
    *outReason = NULL;

    @try {
        throw;
    } @catch (NSException *exception) {
        *outName = exception.name.UTF8String;
        *outReason = exception.reason.UTF8String;

        NSArray<NSNumber *> *addresses = exception.callStackReturnAddresses;
        NSUInteger numFrames = addresses.count;

        if (numFrames == 0) {
            sentrycrashsc_initSelfThread(outCursor, 0);
            return NULL;
        }

        uintptr_t *callstack = (uintptr_t *)malloc(numFrames * sizeof(*callstack));
        if (callstack == NULL) {
            sentrycrashsc_initSelfThread(outCursor, 0);
            return NULL;
        }

        for (NSUInteger i = 0; i < numFrames; i++) {
            callstack[i] = (uintptr_t)addresses[i].unsignedLongLongValue;
        }
        sentrycrashsc_initWithBacktrace(outCursor, callstack, (int)numFrames, 0);
        return callstack;
    } @catch (id exception) {
        return NULL;
    }
}
