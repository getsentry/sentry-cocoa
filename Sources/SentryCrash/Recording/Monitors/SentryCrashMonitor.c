// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor.c
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

#include "SentryCrashMonitor.h"
#include "SentryCrashMonitorContext.h"
#include "SentryCrashMonitorType.h"

#include "SentryCrashDebug.h"
#include "SentryCrashMachineContext.h"
#include "SentryCrashMonitor_AppState.h"
#include "SentryCrashMonitor_CPPException.h"
#include "SentryCrashMonitor_MachException.h"
#include "SentryCrashMonitor_NSException.h"
#include "SentryCrashMonitor_Signal.h"
#include "SentryCrashMonitor_System.h"
#include "SentryCrashThread.h"
#include "SentryInternalCDefines.h"

#include <memory.h>

#include "SentryAsyncSafeLog.h"
#include <pthread.h>
#include <stdatomic.h>
#include <unistd.h>

// ============================================================================
#pragma mark - Globals -
// ============================================================================

typedef struct {
    SentryCrashMonitorType monitorType;
    SentryCrashMonitorAPI *(*getAPI)(void);
} Monitor;

static Monitor g_monitors[] = {
#if SENTRY_HAS_MACH
    {
        .monitorType = SentryCrashMonitorTypeMachException,
        .getAPI = sentrycrashcm_machexception_getAPI,
    },
#endif
#if SENTRY_HAS_SIGNAL
    {
        .monitorType = SentryCrashMonitorTypeSignal,
        .getAPI = sentrycrashcm_signal_getAPI,
    },
#endif
    {
        .monitorType = SentryCrashMonitorTypeNSException,
        .getAPI = sentrycrashcm_nsexception_getAPI,
    },
    {
        .monitorType = SentryCrashMonitorTypeCPPException,
        .getAPI = sentrycrashcm_cppexception_getAPI,
    },
    {
        .monitorType = SentryCrashMonitorTypeApplicationState,
        .getAPI = sentrycrashcm_appstate_getAPI,
    },
};
static int g_monitorsCount = sizeof(g_monitors) / sizeof(*g_monitors);

static SentryCrashMonitorType g_activeMonitors = SentryCrashMonitorTypeNone;

static _Atomic bool g_isHandlingFatalException = false;
static _Atomic bool g_crashedDuringExceptionHandling = false;
static _Atomic pthread_t g_crashingThread = 0;
static bool g_requiresAsyncSafety = false;

static void (*g_onExceptionEvent)(struct SentryCrash_MonitorContext *monitorContext);

// ============================================================================
#pragma mark - API -
// ============================================================================

static inline SentryCrashMonitorAPI *
getAPI(Monitor *monitor)
{
    if (monitor != NULL && monitor->getAPI != NULL) {
        return monitor->getAPI();
    }
    return NULL;
}

static inline void
setMonitorEnabled(Monitor *monitor, bool isEnabled)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->setEnabled != NULL) {
        api->setEnabled(isEnabled);
    }
}

static inline bool
isMonitorEnabled(Monitor *monitor)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->isEnabled != NULL) {
        return api->isEnabled();
    }
    return false;
}

static inline void
addContextualInfoToEvent(Monitor *monitor, struct SentryCrash_MonitorContext *eventContext)
{
    SentryCrashMonitorAPI *api = getAPI(monitor);
    if (api != NULL && api->addContextualInfoToEvent != NULL) {
        api->addContextualInfoToEvent(eventContext);
    }
}

void
sentrycrashcm_setEventCallback(SentryCrashMonitorEventCallback onEvent)
{
    g_onExceptionEvent = onEvent;
}

SentryCrashMonitorEventCallback
sentrycrashcm_getEventCallback(void)
{
    return g_onExceptionEvent;
}

void
sentrycrashcm_setActiveMonitors(SentryCrashMonitorType monitorTypes)
{
    if (sentrycrashdebug_isBeingTraced() && (monitorTypes & SentryCrashMonitorTypeDebuggerUnsafe)) {
        static bool hasWarned = false;
        if (!hasWarned) {
            hasWarned = true;
            SENTRY_ASYNC_SAFE_LOG_WARN("App is running in a debugger. Masking out unsafe monitors. "
                                       "This means that most crashes WILL "
                                       "NOT BE RECORDED while debugging!");
        }
        monitorTypes &= SentryCrashMonitorTypeDebuggerSafe;
    }
    if (g_requiresAsyncSafety && (monitorTypes & SentryCrashMonitorTypeAsyncUnsafe)) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Async-safe environment detected. Masking out unsafe monitors.");
        monitorTypes &= SentryCrashMonitorTypeAsyncSafe;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG(
        "Changing active monitors from 0x%x tp 0x%x.", g_activeMonitors, monitorTypes);

    SentryCrashMonitorType activeMonitors = SentryCrashMonitorTypeNone;
    for (int i = 0; i < g_monitorsCount; i++) {
        Monitor *monitor = &g_monitors[i];
        bool isEnabled = monitor->monitorType & monitorTypes;
        setMonitorEnabled(monitor, isEnabled);
        if (isMonitorEnabled(monitor)) {
            activeMonitors |= monitor->monitorType;
        } else {
            activeMonitors &= ~monitor->monitorType;
        }
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Active monitors are now 0x%x.", activeMonitors);
    g_activeMonitors = activeMonitors;
}

SentryCrashMonitorType
sentrycrashcm_getActiveMonitors(void)
{
    return g_activeMonitors;
}

// ============================================================================
#pragma mark - Private API -
// ============================================================================

void
sentrycrashcm_notifyFatalException(
    bool isAsyncSafeEnvironment, thread_act_array_t *threads, mach_msg_type_number_t *numThreads)
{
    // Subset of KSCrash's notifyException() decision logic, we only do fatal exception handling.
    // https://github.com/kstenerud/KSCrash/blob/master/Sources/KSCrashRecordingCore/KSCrashMonitor.c
    //
    // If another exception occurs while we are already handling an exception, we
    // need to decide what to do based on whether the exception is fatal and whether
    // there's already a handler running on this thread (i.e. our handler has
    // crashed).
    //
    // | 1st exc | 2nd exc | same handler thread? | Procedure        |
    // | ------- | ------- | -------------------- | ---------------- |
    // | any     |         |                      | normal handling  |
    // | fatal   | any     | N                    | block            |
    // | any     | any     | Y                    | recrash handling |
    //
    // Where:
    // - Normal handling means build a standard crash report.
    // - Recrash handling means build a minimal recrash report and be very cautious.
    // - Block means block this thread for a few seconds so it doesn't return
    //   before the other handler does.

    g_requiresAsyncSafety |= isAsyncSafeEnvironment;

    // pthread_self() is not listed as async-signal-safe on xOS but is
    // unlikely to be a problem in practice. Accepted trade-off.
    const pthread_t self = pthread_self();

    bool expected = false;
    const bool wasHandlingFatalException
        = !atomic_compare_exchange_strong(&g_isHandlingFatalException, &expected, true);

    // Record the crashing thread right after winning the CAS so that a
    // re-entrant signal on the same thread always takes the recrash path.
    if (!wasHandlingFatalException) {
        atomic_store(&g_crashingThread, self);
    }

    const bool isCrashedDuringExceptionHandling
        = wasHandlingFatalException && (atomic_load(&g_crashingThread) == self);

    if (isCrashedDuringExceptionHandling) {
        // This is a recrash, so be more conservative in our handling.
        atomic_store(&g_crashedDuringExceptionHandling, true);
        SENTRY_ASYNC_SAFE_LOG_INFO(
            "Detected crash in the crash reporter. Uninstalling SentryCrash.");
        sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    } else if (wasHandlingFatalException) {
        // This is an incidental exception that happened while we were handling a
        // fatal exception. Pause this handler to allow the other handler to finish.
        // 2 seconds should be ample time for it to finish and terminate the app.
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Concurrent crash from different thread. Blocking to let first handler finish.");
        sleep(2);
    }

    // Suspend after the concurrency check so a blocked thread never freezes
    // the first handler.
    if (threads != NULL && numThreads != NULL) {
        sentrycrashmc_suspendEnvironment(threads, numThreads);
    }
}

void
sentrycrashcm_handleException(struct SentryCrash_MonitorContext *context)
{
    context->requiresAsyncSafety = g_requiresAsyncSafety;
    if (g_crashedDuringExceptionHandling) {
        context->crashedDuringCrashHandling = true;
    }
    for (int i = 0; i < g_monitorsCount; i++) {
        Monitor *monitor = &g_monitors[i];
        if (isMonitorEnabled(monitor)) {
            addContextualInfoToEvent(monitor, context);
        }
    }

    g_onExceptionEvent(context);

    if (g_isHandlingFatalException && !g_crashedDuringExceptionHandling) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Exception is fatal. Restoring original handlers.");
        sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
    }
}

void
sentrycrashcm_resetState(void)
{
    atomic_store(&g_isHandlingFatalException, false);
    atomic_store(&g_crashedDuringExceptionHandling, false);
    atomic_store(&g_crashingThread, (pthread_t)0);
    g_requiresAsyncSafety = false;
}
