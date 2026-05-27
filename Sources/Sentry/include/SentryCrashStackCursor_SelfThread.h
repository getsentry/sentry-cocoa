// Sentry-specific self-thread stack cursor with Swift async stitching support.
//
// sentrycrashsc_initSelfThread wraps kssc_initSelfThread but also supports
// backtrace_async for Swift async coroutine stitching.

#ifndef SentryCrashStackCursor_SelfThread_h
#define SentryCrashStackCursor_SelfThread_h

#include "SentryCrashStackCursor.h"

#ifdef __cplusplus
extern "C" {
#endif

/** Initialize a stack cursor for the current thread.
 *
 * @param cursor The stack cursor to initialize.
 *
 * @param skipEntries The number of stack entries to skip.
 */
void sentrycrashsc_initSelfThread(SentryCrashStackCursor *cursor, int skipEntries);

#ifdef __cplusplus
}
#endif

#endif // SentryCrashStackCursor_SelfThread_h
