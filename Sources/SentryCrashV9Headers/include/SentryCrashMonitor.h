// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor.h
//
//  Created by Karl Stenerud on 2012-02-12.
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

/** Keeps watch for crashes and informs via callback when on occurs.
 */

#ifndef HDR_SentryCrashMonitor_h
#define HDR_SentryCrashMonitor_h

#include "SentryCrashMonitorType.h"
#include "SentryCrashThread.h"

#include <mach/mach.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

struct SentryCrash_MonitorContext;

// ============================================================================
#pragma mark - External API -
// ============================================================================

/** Set which monitors are active.
 *
 * @param monitorTypes Which monitors should be active.
 */
void sentrycrashcm_setActiveMonitors(SentryCrashMonitorType monitorTypes);

/** Get the currently active monitors.
 */
SentryCrashMonitorType sentrycrashcm_getActiveMonitors(void);

typedef void (*SentryCrashMonitorEventCallback)(struct SentryCrash_MonitorContext *);

/** Set the callback to call when an event is captured.
 *
 * @param onEvent Called whenever an event is captured.
 */
void sentrycrashcm_setEventCallback(SentryCrashMonitorEventCallback onEvent);

/** Get the current SentryCrashMonitorEventCallback. Only needed for testing.
 *
 */
SentryCrashMonitorEventCallback sentrycrashcm_getEventCallback(void);

// ============================================================================
#pragma mark - Internal API -
// ============================================================================

typedef struct {
    void (*setEnabled)(bool isEnabled);
    bool (*isEnabled)(void);
    void (*addContextualInfoToEvent)(struct SentryCrash_MonitorContext *eventContext);
} SentryCrashMonitorAPI;

/** Notify that a fatal exception has been captured, then suspend the
 * runtime environment. Combining both into one call ensures the concurrency
 * check always runs before any threads are suspended, preventing a deadlock
 * where a second crashing thread freezes the first handler.
 *
 * Simplified version of KSCrash's notifyException() decision logic.
 * See:
 * https://github.com/kstenerud/KSCrash/blob/master/Sources/KSCrashRecordingCore/KSCrashMonitor.c
 *
 * @param isAsyncSafeEnvironment If true, only async-safe functions are allowed
 * from now on.
 * @param threads Out-param for suspended threads. Pass NULL to skip suspension.
 * @param numThreads Out-param for count of suspended threads. Pass NULL to skip.
 */
void sentrycrashcm_notifyFatalException(
    bool isAsyncSafeEnvironment, thread_act_array_t *threads, mach_msg_type_number_t *numThreads);

/** Start general exception processing.
 *
 * @oaram context Contextual information about the exception.
 */
void sentrycrashcm_handleException(struct SentryCrash_MonitorContext *context);

/** Reset the crash handling state.
 * Called on uninstall to clear state between sessions.
 */
void sentrycrashcm_resetState(void);

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashMonitor_h
