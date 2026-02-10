// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashCachedData.h
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

/** Maintains a cache of thread information that would be difficult to retrieve
 *  during a crash, such as thread names and dispatch queue names.
 *
 *  The cache uses lock-free atomic operations for thread safety. A background
 *  thread periodically updates the cache, and crash handlers can acquire
 *  exclusive access using sentrycrashccd_freeze/sentrycrashccd_unfreeze.
 *
 *  Usage pattern:
 *    sentrycrashccd_freeze();     // Acquire exclusive access
 *    // ... call getThreadName / getQueueName ...
 *    sentrycrashccd_unfreeze();   // Release access
 */

#ifndef SentryCrashCachedData_h
#define SentryCrashCachedData_h

#include "SentryCrashThread.h"

#include <stdbool.h>

/** Initialize the thread cache and start the background monitoring thread.
 *
 *  @param pollingIntervalInSeconds How often to refresh the thread cache.
 */
void sentrycrashccd_init(int pollingIntervalInSeconds);

/** Stop the background monitoring thread and free all cached data. */
void sentrycrashccd_close(void);

/** Check whether the background monitoring thread has been started.
 *
 *  @return true if init() was called and close() has not been called.
 */
bool sentrycrashccd_hasThreadStarted(void);

/** Freeze the cache to prevent updates during crash handling.
 *
 *  This atomically acquires exclusive access to the cache so the background
 *  thread cannot modify or free it while the crash handler reads from it.
 *  Must be paired with sentrycrashccd_unfreeze().
 */
void sentrycrashccd_freeze(void);

/** Unfreeze the cache to allow the background thread to resume updates.
 *
 *  Releases exclusive access acquired by sentrycrashccd_freeze().
 */
void sentrycrashccd_unfreeze(void);

/** Get the name of a thread from the cache.
 *
 *  Must be called between sentrycrashccd_freeze() and sentrycrashccd_unfreeze().
 *
 *  @param thread The mach thread to look up.
 *  @return The thread name, or NULL if not found or cache unavailable.
 */
const char *sentrycrashccd_getThreadName(SentryCrashThread thread);

/** Get the dispatch queue name of a thread from the cache.
 *
 *  @note Not yet implemented — always returns NULL. KSCrash upstream populates
 *  queue names via ksthread_getQueueName() using THREAD_IDENTIFIER_INFO.
 *
 *  @param thread The mach thread to look up.
 *  @return Always NULL (queue name caching not implemented).
 */
const char *sentrycrashccd_getQueueName(SentryCrashThread thread);

#endif /* SentryCrashCachedData_h */
