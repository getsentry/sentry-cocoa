// Adapted from KSCrashMonitor_Signal.c.
// Copyright (c) 2012 Karl Stenerud. All rights reserved.
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

#if SDK_V10

#    include "SentryKSCrashManagedSignal.h"
#    include "KSMach.h"
#    include "KSMachineContext.h"
#    include "KSSignalInfo.h"
#    include "KSStackCursor_MachineContext.h"
#    include "KSThread.h"
#    include "SentryInternalCDefines.h"
#    include "Unwind/KSStackCursor_Unwind.h"
#    include <pthread.h>
#    include <signal.h>
#    include <stdatomic.h>
#    include <stdlib.h>

// Signal-monitor synchronization baseline:
// KSCrashMonitor_Signal.c at 18a633dec20c265f03386294f9d82d208bb13094.
// See develop-docs/KSCrash_MANAGED_SIGNAL_PLUGIN_MAINTENANCE.md before changing the KSCrash pin.

// SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: downstream build policy, not a KSCrash global mode.
bool
sentrykscrash_isManagedRuntimeBuild(void)
{
#    ifdef SENTRY_CRASH_MANAGED_RUNTIME
    return true;
#    else
    return false;
#    endif
}

uint32_t
sentrykscrash_managedMachExceptionMask(void)
{
#    if defined(__APPLE__)
    return EXC_MASK_BAD_INSTRUCTION | EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT;
#    else
    return 0;
#    endif
}

// SENTRY MANAGED SIGNAL DIFFERENCE END

#    if SENTRY_HAS_SIGNAL

typedef enum {
    SentryManagedSignalNotInstalled = 0,
    SentryManagedSignalInstalling,
    SentryManagedSignalInstalled,
    SentryManagedSignalUninstalled,
    SentryManagedSignalFailedInstall,
} SentryManagedSignalInstalledState;

typedef struct SentryIgnoredSignal {
    _Atomic uintptr_t thread;
    _Atomic int signal;
    struct SentryIgnoredSignal *next;
} SentryIgnoredSignal;

static _Atomic(SentryIgnoredSignal *) g_ignoredSignals;
static pthread_key_t g_ignoredSignalKey;
static bool g_ignoredSignalKeyCreated;
static pthread_once_t g_ignoredSignalKeyOnce = PTHREAD_ONCE_INIT;

static struct {
    _Atomic(SentryManagedSignalInstalledState) installedState;
    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: interrupted installation may restore only entries
    // published here. Each predecessor is immutable after this release/acquire publication.
    atomic_int restorableHandlerCount;
    // SENTRY MANAGED SIGNAL DIFFERENCE END
    atomic_bool enabled;
    // One initializer owns the copy; readers use only the separately published readiness flag.
    atomic_bool callbacksClaimed;
    atomic_bool callbacksReady;
#        if SENTRY_HAS_SIGNAL_STACK
    stack_t signalStack;
#        endif
    struct sigaction *previousHandlers;
    KSCrash_ExceptionHandlerCallbacks callbacks;
} g_managedSignal;

_Static_assert(ATOMIC_INT_LOCK_FREE == 2, "Signal-handler installation state must be lock-free");
_Static_assert(ATOMIC_BOOL_LOCK_FREE == 2, "Signal-handler enablement must be lock-free");
_Static_assert(ATOMIC_POINTER_LOCK_FREE == 2, "Signal-handler list publication must be lock-free");
_Static_assert(__atomic_always_lock_free(sizeof(uintptr_t), 0),
    "Signal-handler thread identity must be lock-free");

static void sentrykscrash_managedSignalRestoreHandlers(void);

// SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: downstream per-thread, one-shot suppression.
static void
sentrykscrash_clearIgnoredSignal(void *value)
{
    SentryIgnoredSignal *entry = value;
    atomic_store_explicit(&entry->signal, 0, memory_order_relaxed);
    atomic_store_explicit(&entry->thread, 0, memory_order_relaxed);
}

static void
sentrykscrash_createIgnoredSignalKey(void)
{
    g_ignoredSignalKeyCreated
        = pthread_key_create(&g_ignoredSignalKey, sentrykscrash_clearIgnoredSignal) == 0;
}

static bool
sentrykscrash_consumeIgnoredSignal(int signal)
{
    SentryIgnoredSignal *entry = atomic_load_explicit(&g_ignoredSignals, memory_order_acquire);
    if (entry == NULL) {
        return false;
    }

    // On Apple platforms pthread_self() reads the initialized direct TSD slot. Do not replace it
    // with pthread_getspecific() in this signal-handler path.
    const uintptr_t thread = (uintptr_t)pthread_self();
    while (entry != NULL) {
        if (atomic_load_explicit(&entry->thread, memory_order_relaxed) == thread) {
            // Consume on the next delivery even when the signal number does not match. This is
            // the established hybrid-SDK SPI contract.
            return atomic_exchange_explicit(&entry->signal, 0, memory_order_relaxed) == signal;
        }
        entry = entry->next;
    }
    return false;
}

// SENTRY MANAGED SIGNAL DIFFERENCE END

static void
sentrykscrash_managedSignalRestoreHandlersUpTo(const int *signals, int count)
{
    for (int i = 0; i < count; i++) {
        if (g_managedSignal.previousHandlers[i].sa_handler != SIG_IGN) {
            sigaction(signals[i], &g_managedSignal.previousHandlers[i], NULL);
        }
    }
}

// SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: a second handler may enter after restoration starts but
// before its own predecessor is restored. Restore that immutable entry directly before re-raising;
// duplicate sigaction calls write the same value and never require signal-path coordination.
static void
sentrykscrash_managedSignalRestoreHandler(int signal)
{
    const int *signals = kssignal_fatalSignals();
    const int count
        = atomic_load_explicit(&g_managedSignal.restorableHandlerCount, memory_order_acquire);
    for (int i = 0; i < count; i++) {
        if (signals[i] == signal) {
            if (g_managedSignal.previousHandlers[i].sa_handler != SIG_IGN) {
                sigaction(signal, &g_managedSignal.previousHandlers[i], NULL);
            }
            return;
        }
    }
}
// SENTRY MANAGED SIGNAL DIFFERENCE END

static void
sentrykscrash_managedSignalHandler(int signal, siginfo_t *signalInfo, void *userContext)
{
    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: an anchor may run before KSCrash adopts it.
    const bool ignored = sentrykscrash_consumeIgnoredSignal(signal);
    const bool canReport = atomic_load_explicit(&g_managedSignal.enabled, memory_order_acquire)
        && atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire)
            == SentryManagedSignalInstalled
        && atomic_load_explicit(&g_managedSignal.callbacksReady, memory_order_acquire);
    // SENTRY MANAGED SIGNAL DIFFERENCE END

    if (canReport && !ignored) {
        KSCrash_MonitorContext *context
            = g_managedSignal.callbacks.notify((thread_t)ksthread_self(),
                (KSCrash_ExceptionHandlingRequirements) { .asyncSafety = true,
                    .isFatal = true,
                    .isCleanExit = (signal == SIGTERM),
                    .shouldRecordAllThreads = (signal != SIGTERM),
                    .shouldWriteReport = (signal != SIGTERM) });
        if (context != NULL && !context->requirements.shouldExitImmediately) {
            KSStackCursor stackCursor = { 0 };
            KSMachineContext machineContext = { 0 };
            ksmc_getContextForSignal(userContext, &machineContext);
            kssc_initWithUnwind(&stackCursor, KSSC_MAX_STACK_DEPTH, &machineContext);

            context->monitorId = "Signal";
            context->monitorFlags = KSCrashMonitorFlagAsyncSafe | KSCrashMonitorFlagPlugin;
            context->offendingMachineContext = &machineContext;
            context->registersAreValid = true;
            context->faultAddress = (uintptr_t)signalInfo->si_addr;
            context->signal.userContext = userContext;
            context->signal.signum = signalInfo->si_signo;
            context->signal.sigcode = signalInfo->si_code;
            context->mach.type = ksmach_machExceptionForSignal(signalInfo->si_signo);
            context->stackCursor = &stackCursor;
            g_managedSignal.callbacks.handle(context);
        }
    }

    // Keep the constructor-installed anchor for the process lifetime, but a fatal delivery is a
    // one-way path: restore the system predecessor before forwarding exactly as KSCrash does.
    sentrykscrash_managedSignalRestoreHandlers();
    sentrykscrash_managedSignalRestoreHandler(signal);
    raise(signal);
}

#        if SENTRY_HAS_SIGNAL_STACK
// SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: only used before any anchor has become reachable.
// After exposure, even a failed install retains its allocations: handlers may still use them.
static void
sentrykscrash_managedSignalReleaseUnusedStack(bool registered)
{
    if (g_managedSignal.signalStack.ss_sp == NULL) {
        return;
    }
    if (registered) {
        stack_t currentStack = { 0 };
        if (sigaltstack(NULL, &currentStack) != 0 || (currentStack.ss_flags & SS_ONSTACK)) {
            return;
        }
        if (!(currentStack.ss_flags & SS_DISABLE)) {
            // Never alter a replacement owner's stack or assume it cannot reference our buffer.
            if (currentStack.ss_sp != g_managedSignal.signalStack.ss_sp
                || currentStack.ss_size != g_managedSignal.signalStack.ss_size) {
                return;
            }
            // Darwin requires ss_size >= MINSIGSTKSZ even for SS_DISABLE. Replaying the original
            // zero-sized disabled descriptor fails with ENOMEM, so retain our valid size.
            stack_t disabledStack = g_managedSignal.signalStack;
            disabledStack.ss_flags = SS_DISABLE;
            if (sigaltstack(&disabledStack, NULL) != 0) {
                return;
            }
        }
    }
    free(g_managedSignal.signalStack.ss_sp);
    g_managedSignal.signalStack = (stack_t) { 0 };
}
// SENTRY MANAGED SIGNAL DIFFERENCE END
#        endif

static void
sentrykscrash_managedSignalInstall(void)
{
    SentryManagedSignalInstalledState expected = SentryManagedSignalNotInstalled;
    if (!atomic_compare_exchange_strong_explicit(&g_managedSignal.installedState, &expected,
            SentryManagedSignalInstalling, memory_order_acq_rel, memory_order_acquire)) {
        return;
    }

    bool handlersExposed = false;
#        if SENTRY_HAS_SIGNAL_STACK
    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: sigaltstack belongs to the installing thread,
    // not the monitor. Borrow an existing stack (including SS_ONSTACK); never replace it.
    bool stackRegistered = false;
    stack_t previousStack = { 0 };
    if (sigaltstack(NULL, &previousStack) != 0) {
        goto failed;
    }
    if (previousStack.ss_flags & SS_DISABLE) {
        g_managedSignal.signalStack.ss_size = SIGSTKSZ;
        g_managedSignal.signalStack.ss_sp = malloc(g_managedSignal.signalStack.ss_size);
        if (g_managedSignal.signalStack.ss_sp == NULL
            || sigaltstack(&g_managedSignal.signalStack, NULL) != 0) {
            goto failed;
        }
        stackRegistered = true;
    }
    // SENTRY MANAGED SIGNAL DIFFERENCE END
#        endif

    const int *signals = kssignal_fatalSignals();
    const int count = kssignal_numFatalSignals();
    g_managedSignal.previousHandlers = calloc((size_t)count, sizeof(struct sigaction));
    if (g_managedSignal.previousHandlers == NULL) {
        goto failed;
    }

    struct sigaction action = { 0 };
    action.sa_flags = SA_SIGINFO | SA_ONSTACK;
#        if defined(__APPLE__) && defined(__LP64__)
    action.sa_flags |= SA_64REGSET;
#        endif
    sigemptyset(&action.sa_mask);
    action.sa_sigaction = sentrykscrash_managedSignalHandler;

    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: publish the captured prefix before exposing each
    // anchor, not Installed before capturing any predecessors. A signal can interrupt sigaction
    // itself, on this thread or another thread, and restoration must stop further installation.
    for (int i = 0; i < count; i++) {
        if (atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire)
            != SentryManagedSignalInstalling) {
            return;
        }
        if (sigaction(signals[i], NULL, &g_managedSignal.previousHandlers[i]) != 0) {
            goto failed;
        }
        atomic_store_explicit(&g_managedSignal.restorableHandlerCount, i + 1, memory_order_release);
        if (g_managedSignal.previousHandlers[i].sa_handler == SIG_IGN) {
            continue;
        }
        if (atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire)
            != SentryManagedSignalInstalling) {
            return;
        }
        if (sigaction(signals[i], &action, NULL) != 0) {
            goto failed;
        }
        handlersExposed = true;
        if (atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire)
            != SentryManagedSignalInstalling) {
            // Restoration may have run before this in-flight sigaction installed the anchor.
            // Undo that final write as well; never resume installation after a fatal delivery.
            sigaction(signals[i], &g_managedSignal.previousHandlers[i], NULL);
            return;
        }
    }
    expected = SentryManagedSignalInstalling;
    atomic_compare_exchange_strong_explicit(&g_managedSignal.installedState, &expected,
        SentryManagedSignalInstalled, memory_order_acq_rel, memory_order_acquire);
    return;

failed:
    sentrykscrash_managedSignalRestoreHandlers();
    atomic_store_explicit(
        &g_managedSignal.installedState, SentryManagedSignalFailedInstall, memory_order_release);
    if (!handlersExposed) {
        // No Sentry handler can hold these pointers. This path is installation-time only, never
        // signal-time cleanup. Once any sigaction succeeds, reclamation is no longer safe.
        atomic_store_explicit(&g_managedSignal.restorableHandlerCount, 0, memory_order_release);
        free(g_managedSignal.previousHandlers);
        g_managedSignal.previousHandlers = NULL;
#        if SENTRY_HAS_SIGNAL_STACK
        sentrykscrash_managedSignalReleaseUnusedStack(stackRegistered);
#        endif
    }
    // SENTRY MANAGED SIGNAL DIFFERENCE END
}

static void
sentrykscrash_managedSignalRestoreHandlers(void)
{
    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: an anchor can run before installation finishes.
    SentryManagedSignalInstalledState expected
        = atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire);
    while (expected == SentryManagedSignalInstalling || expected == SentryManagedSignalInstalled) {
        if (atomic_compare_exchange_strong_explicit(&g_managedSignal.installedState, &expected,
                SentryManagedSignalUninstalled, memory_order_acq_rel, memory_order_acquire)) {
            sentrykscrash_managedSignalRestoreHandlersUpTo(kssignal_fatalSignals(),
                atomic_load_explicit(
                    &g_managedSignal.restorableHandlerCount, memory_order_acquire));
            return;
        }
    }
    // SENTRY MANAGED SIGNAL DIFFERENCE END
}

static void
sentrykscrash_managedSignalInit(KSCrash_ExceptionHandlerCallbacks *callbacks, void *context)
{
    (void)context;
    if (callbacks == NULL) {
        return;
    }
    // SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: KSCrash's reporting functions are process-lifetime.
    // Copy only what this monitor uses, and never overwrite storage a handler may already read.
    // Invalid input must not claim initialization, so a later complete table can still be adopted.
    const KSCrash_ExceptionHandlerCallbacks snapshot = {
        .notify = callbacks->notify,
        .handle = callbacks->handle,
    };
    if (snapshot.notify == NULL || snapshot.handle == NULL) {
        return;
    }
    bool expected = false;
    if (!atomic_compare_exchange_strong_explicit(&g_managedSignal.callbacksClaimed, &expected, true,
            memory_order_acq_rel, memory_order_acquire)) {
        return;
    }
    g_managedSignal.callbacks = snapshot;
    // An interrupting signal observes not-ready and forwards; it must never wait on this writer.
    atomic_store_explicit(&g_managedSignal.callbacksReady, true, memory_order_release);
    // SENTRY MANAGED SIGNAL DIFFERENCE END
}

static const char *
sentrykscrash_managedSignalMonitorId(void *context)
{
    (void)context;
    // Preserve KSCrash's standard signal report section and converter behavior.
    return "Signal";
}

static KSCrashMonitorFlag
sentrykscrash_managedSignalFlags(void *context)
{
    (void)context;
    return KSCrashMonitorFlagAsyncSafe | KSCrashMonitorFlagPlugin;
}

static void
sentrykscrash_managedSignalSetEnabled(bool enabled, void *context)
{
    (void)context;
    atomic_store_explicit(&g_managedSignal.enabled, enabled, memory_order_release);
    if (enabled) {
        sentrykscrash_managedSignalInstall();
    }
}

static bool
sentrykscrash_managedSignalIsEnabled(void *context)
{
    (void)context;
    return atomic_load_explicit(&g_managedSignal.enabled, memory_order_acquire)
        && atomic_load_explicit(&g_managedSignal.installedState, memory_order_acquire)
        == SentryManagedSignalInstalled;
}

static void
sentrykscrash_managedSignalAddContext(KSCrash_MonitorContext *eventContext, void *context)
{
    (void)eventContext;
    (void)context;
}

static void
sentrykscrash_managedSignalNotify(void *context)
{
    (void)context;
}

#    endif // SENTRY_HAS_SIGNAL

// SENTRY MANAGED SIGNAL DIFFERENCE BEGIN: plugin registration and pre-SDK anchor ownership.
KSCrashMonitorAPI *
sentrykscrash_managedSignalMonitorAPI(void)
{
    static KSCrashMonitorAPI api = {
#    if SENTRY_HAS_SIGNAL
        .init = sentrykscrash_managedSignalInit,
        .monitorId = sentrykscrash_managedSignalMonitorId,
        .monitorFlags = sentrykscrash_managedSignalFlags,
        .setEnabled = sentrykscrash_managedSignalSetEnabled,
        .isEnabled = sentrykscrash_managedSignalIsEnabled,
        .addContextualInfoToEvent = sentrykscrash_managedSignalAddContext,
        .notifyPostMonitorsEnabled = sentrykscrash_managedSignalNotify,
        .notifyPostSystemEnable = sentrykscrash_managedSignalNotify,
#    endif
    };
    return &api;
}

void
sentrykscrash_ignoreNextSignal(int signal)
{
#    if SENTRY_HAS_SIGNAL
    if (pthread_once(&g_ignoredSignalKeyOnce, sentrykscrash_createIgnoredSignalKey) != 0
        || !g_ignoredSignalKeyCreated) {
        return;
    }

    SentryIgnoredSignal *entry = pthread_getspecific(g_ignoredSignalKey);
    if (entry == NULL) {
        // The signal handler traverses this append-only list, so entries are intentionally
        // retained.
        entry = calloc(1, sizeof(*entry));
        if (entry == NULL || pthread_setspecific(g_ignoredSignalKey, entry) != 0) {
            free(entry);
            return;
        }
        atomic_store_explicit(&entry->thread, (uintptr_t)pthread_self(), memory_order_relaxed);
        SentryIgnoredSignal *head = atomic_load_explicit(&g_ignoredSignals, memory_order_relaxed);
        do {
            entry->next = head;
        } while (!atomic_compare_exchange_weak_explicit(
            &g_ignoredSignals, &head, entry, memory_order_release, memory_order_relaxed));
    }
    atomic_store_explicit(&entry->signal, signal, memory_order_relaxed);
#    else
    (void)signal;
#    endif
}

#    if defined(SENTRY_CRASH_MANAGED_RUNTIME) && SENTRY_HAS_SIGNAL
/** Install the downstream-owned chain anchor before Mono/.NET initializes. */
__attribute__((constructor)) static void
sentrykscrash_prepareManagedSignalMonitor(void)
{
    sentrykscrash_managedSignalInstall();
}
#    endif

// SENTRY MANAGED SIGNAL DIFFERENCE END

#endif // SDK_V10
