#ifndef SentryThreadInfoCheck_hpp
#define SentryThreadInfoCheck_hpp

/**
 * These functions provide pure C++ implementations of checking queue and thread info pointers that
 * are not possible in ARC contexts ie ObjC++. It also contains a private reimplementation of
 * `isMemoryReadable` from `SentryCrashMemory.c` which can't be included here due to its use of the
 * `restrict` keyword, and anyways, it's better to minimize coupling point between `Sentry` and
 * `SentryCrash`.
 */

#include <mach/mach.h>
#include <stdio.h>

bool isValidQueuePointer(thread_identifier_info_t idInfo);

bool isValidThreadInfo(thread_identifier_info_t idInfo);

#endif /* SentryThreadInfoCheck_hpp */
