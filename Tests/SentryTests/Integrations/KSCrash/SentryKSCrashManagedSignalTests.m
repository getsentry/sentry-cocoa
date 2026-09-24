#if SDK_V10

#    import <XCTest/XCTest.h>

#    include "KSMachineContext.h"
#    include "SentryInternalCDefines.h"
#    include "Unwind/KSStackCursor_Unwind.h"
#    include <errno.h>
#    include <signal.h>
#    include <stdatomic.h>
#    include <stdlib.h>
#    include <string.h>

#    if SENTRY_HAS_SIGNAL

static int testSigaction(int signal, const struct sigaction *action, struct sigaction *previous);
#        if SENTRY_HAS_SIGNAL_STACK
static int testSigaltstack(const stack_t *stack, stack_t *previous);
static void *testMalloc(size_t size);
#        endif
static int testRaise(int signal);
static void *testCalloc(size_t count, size_t size);
static void testFree(void *pointer);
static bool testGetContextForSignal(void *userContext, struct KSMachineContext *context);
static void testInitWithUnwind(
    KSStackCursor *cursor, int depth, const struct KSMachineContext *context);
static void testBeforeAtomicStore(const volatile void *object);

// Compile an isolated copy of the real monitor with fake syscalls. This lets a test deliver a
// signal at an exact installation boundary without replacing XCTest's handlers, exporting test
// hooks, or maintaining a second implementation of the installation algorithm.
#        define sigaction(...) testSigaction(__VA_ARGS__)
#        define sigaltstack(...) testSigaltstack(__VA_ARGS__)
#        define raise(...) testRaise(__VA_ARGS__)
#        define malloc(...) testMalloc(__VA_ARGS__)
#        define calloc(...) testCalloc(__VA_ARGS__)
#        define free(...) testFree(__VA_ARGS__)
// The mock callbacks inspect report fields without reading a real signal's machine context.
#        define ksmc_getContextForSignal(...) testGetContextForSignal(__VA_ARGS__)
#        define kssc_initWithUnwind(...) testInitWithUnwind(__VA_ARGS__)
// Pause immediately before publication, without adding a hook to production. Use Clang's C11
// primitive for the actual store so the real memory ordering remains intact in this test copy.
#        pragma push_macro("atomic_store_explicit")
#        undef atomic_store_explicit
#        define atomic_store_explicit(object, value, order)                                        \
            do {                                                                                   \
                testBeforeAtomicStore(object);                                                     \
                __c11_atomic_store(object, value, order);                                          \
            } while (0)
#        define sentrykscrash_isManagedRuntimeBuild test_isManagedRuntimeBuild
#        define sentrykscrash_managedMachExceptionMask test_managedMachExceptionMask
#        define sentrykscrash_managedSignalMonitorAPI test_managedSignalMonitorAPI
#        define sentrykscrash_ignoreNextSignal test_ignoreNextSignal
#        pragma push_macro("SENTRY_CRASH_MANAGED_RUNTIME")
#        undef SENTRY_CRASH_MANAGED_RUNTIME
#        include "../../../../Sources/Sentry/KSCrash/SentryKSCrashManagedSignal.c"
#        pragma pop_macro("SENTRY_CRASH_MANAGED_RUNTIME")
#        undef sigaction
#        undef sigaltstack
#        undef raise
#        undef malloc
#        undef calloc
#        undef free
#        undef ksmc_getContextForSignal
#        undef kssc_initWithUnwind
#        pragma pop_macro("atomic_store_explicit")
#        undef sentrykscrash_isManagedRuntimeBuild
#        undef sentrykscrash_managedMachExceptionMask
#        undef sentrykscrash_managedSignalMonitorAPI
#        undef sentrykscrash_ignoreNextSignal

static struct {
    struct sigaction actions[NSIG];
    struct sigaction originals[NSIG];
    struct sigaction actionsAtRaise[NSIG];
    int installCalls;
    int writeCalls;
    int deliverOnInstall;
    bool deliverBeforeInstall;
    bool enabledDuringInstall;
    int queryFailureSignal;
    int installFailureSignal;
    int raiseCalls;
    int raisedSignal;
    bool handlingSignal;
    int restoreWriteCalls;
    int deliverOnRestoreWrite;
    bool deliverBeforeRestoreWrite;
    bool deliveringDuringRestore;
    int nestedSignal;
    int nestedRaiseCalls;
    struct sigaction actionsAtNestedRaise[NSIG];
} g_testSignals;

static struct {
    struct {
        void *pointer;
        bool live;
    } entries[8];
    size_t count;
    bool failMalloc;
    bool failCalloc;
    int invalidFrees;
    int freesInHandler;
} g_testAllocations;

#        if SENTRY_HAS_SIGNAL_STACK
static unsigned char g_hostStack[SIGSTKSZ];
static unsigned char g_replacementStack[SIGSTKSZ];
static struct {
    stack_t current;
    int queries;
    int writes;
    int writesInHandler;
    int failQueryOnCall;
    bool failRegistration;
    bool failDisable;
    bool replaceOnHandlerQueryFailure;
    bool useSystemStack;
} g_testStack;
#        endif

static void *
recordAllocation(void *pointer)
{
    if (pointer != NULL) {
        if (g_testAllocations.count
            >= sizeof(g_testAllocations.entries) / sizeof(g_testAllocations.entries[0])) {
            free(pointer);
            return NULL;
        }
        g_testAllocations.entries[g_testAllocations.count].pointer = pointer;
        g_testAllocations.entries[g_testAllocations.count++].live = true;
    }
    return pointer;
}

#        if SENTRY_HAS_SIGNAL_STACK
static void *
testMalloc(size_t size)
{
    return g_testAllocations.failMalloc ? NULL : recordAllocation(malloc(size));
}
#        endif

static void *
testCalloc(size_t count, size_t size)
{
    return g_testAllocations.failCalloc ? NULL : recordAllocation(calloc(count, size));
}

static void
testFree(void *pointer)
{
    if (pointer == NULL) {
        return;
    }
    g_testAllocations.freesInHandler += g_testSignals.handlingSignal;
    for (size_t i = 0; i < g_testAllocations.count; i++) {
        if (g_testAllocations.entries[i].pointer == pointer && g_testAllocations.entries[i].live) {
            g_testAllocations.entries[i].live = false;
            free(pointer);
            return;
        }
    }
    // Do not let a buggy ownership path actually free a host stack or double-free in XCTest.
    g_testAllocations.invalidFrees++;
}

#        if SENTRY_HAS_SIGNAL_STACK
static size_t
liveAllocations(void)
{
    size_t count = 0;
    for (size_t i = 0; i < g_testAllocations.count; i++) {
        count += g_testAllocations.entries[i].live;
    }
    return count;
}
#        endif

static void
testDeliverSignal(int signal)
{
    g_testSignals.handlingSignal = true;
#        if SENTRY_HAS_SIGNAL_STACK
    const int previousFlags = g_testStack.current.ss_flags;
    if (!(previousFlags & SS_DISABLE)) {
        g_testStack.current.ss_flags |= SS_ONSTACK;
    }
#        endif
    siginfo_t info = { .si_signo = signal };
    sentrykscrash_managedSignalHandler(signal, &info, NULL);
#        if SENTRY_HAS_SIGNAL_STACK
    g_testStack.current.ss_flags = previousFlags;
#        endif
    g_testSignals.handlingSignal = false;
}

static struct {
    atomic_int publications;
    bool deliverBeforePublication;
    bool reinitializeBeforePublication;
    bool readyAfterReinitialization;
    bool reinitializeDuringNotify;
    bool returnNull;
    int notifyA;
    int notifyB;
    int handleA;
    int handleB;
    int contextCalls;
    int unwindCalls;
    KSCrash_MonitorContext context;
    KSCrash_ExceptionHandlingRequirements requirements;
    int reportedSignal;
    bool reportedSignalMonitor;
    bool reportedMachineContext;
    bool reportedStackCursor;
} g_testCallbacks;

static KSCrash_ExceptionHandlerCallbacks testCallbacksB(void);

static KSCrash_MonitorContext *
testNotifyA(thread_t thread, KSCrash_ExceptionHandlingRequirements requirements)
{
    (void)thread;
    g_testCallbacks.notifyA++;
    g_testCallbacks.requirements = requirements;
    if (g_testCallbacks.reinitializeDuringNotify) {
        KSCrash_ExceptionHandlerCallbacks replacement = testCallbacksB();
        sentrykscrash_managedSignalInit(&replacement, NULL);
    }
    return g_testCallbacks.returnNull ? NULL : &g_testCallbacks.context;
}

static KSCrash_MonitorContext *
testNotifyB(thread_t thread, KSCrash_ExceptionHandlingRequirements requirements)
{
    (void)thread;
    g_testCallbacks.notifyB++;
    g_testCallbacks.requirements = requirements;
    return g_testCallbacks.returnNull ? NULL : &g_testCallbacks.context;
}

static void
testHandleA(KSCrash_MonitorContext *context)
{
    g_testCallbacks.handleA++;
    g_testCallbacks.reportedSignal = context->signal.signum;
    g_testCallbacks.reportedSignalMonitor = strcmp(context->monitorId, "Signal") == 0
        && context->monitorFlags == (KSCrashMonitorFlagAsyncSafe | KSCrashMonitorFlagPlugin);
    // These stack-local objects expire when the handler returns. Inspect, but never retain them.
    g_testCallbacks.reportedMachineContext = context->offendingMachineContext != NULL;
    g_testCallbacks.reportedStackCursor = context->stackCursor != NULL;
}

static void
testHandleB(KSCrash_MonitorContext *context)
{
    (void)context;
    g_testCallbacks.handleB++;
}

static KSCrash_ExceptionHandlerCallbacks
testCallbacksA(void)
{
    return (KSCrash_ExceptionHandlerCallbacks) { .notify = testNotifyA, .handle = testHandleA };
}

static KSCrash_ExceptionHandlerCallbacks
testCallbacksB(void)
{
    return (KSCrash_ExceptionHandlerCallbacks) { .notify = testNotifyB, .handle = testHandleB };
}

static bool
testGetContextForSignal(void *userContext, struct KSMachineContext *context)
{
    (void)userContext;
    (void)context;
    g_testCallbacks.contextCalls++;
    return true;
}

static void
testInitWithUnwind(KSStackCursor *cursor, int depth, const struct KSMachineContext *context)
{
    (void)cursor;
    (void)depth;
    (void)context;
    g_testCallbacks.unwindCalls++;
}

typedef struct {
    pthread_mutex_t mutex;
    pthread_cond_t condition;
    size_t arrived;
    bool start;
} CallbackInitGate;

typedef struct {
    CallbackInitGate *gate;
    KSCrash_ExceptionHandlerCallbacks callbacks;
} CallbackInitWorker;

static void *
initializeCallbacksConcurrently(void *value)
{
    CallbackInitWorker *worker = value;
    pthread_mutex_lock(&worker->gate->mutex);
    worker->gate->arrived++;
    pthread_cond_broadcast(&worker->gate->condition);
    while (!worker->gate->start) {
        pthread_cond_wait(&worker->gate->condition, &worker->gate->mutex);
    }
    pthread_mutex_unlock(&worker->gate->mutex);

    for (int i = 0; i < 32; i++) {
        sentrykscrash_managedSignalInit(&worker->callbacks, NULL);
    }
    return NULL;
}

static void
testBeforeAtomicStore(const volatile void *object)
{
    if (object == &g_managedSignal.callbacksReady) {
        atomic_fetch_add_explicit(&g_testCallbacks.publications, 1, memory_order_relaxed);
        if (g_testCallbacks.reinitializeBeforePublication) {
            g_testCallbacks.reinitializeBeforePublication = false;
            KSCrash_ExceptionHandlerCallbacks replacement = testCallbacksB();
            sentrykscrash_managedSignalInit(&replacement, NULL);
            g_testCallbacks.readyAfterReinitialization
                = atomic_load_explicit(&g_managedSignal.callbacksReady, memory_order_acquire);
        }
        if (g_testCallbacks.deliverBeforePublication) {
            g_testCallbacks.deliverBeforePublication = false;
            testDeliverSignal(SIGSEGV);
        }
    }
}

static void
previousHandler(int signal)
{
    (void)signal;
}

static int
testSigaction(int signal, const struct sigaction *action, struct sigaction *previous)
{
    if (previous != NULL) {
        if (signal == g_testSignals.queryFailureSignal) {
#        if SENTRY_HAS_SIGNAL_STACK
            if (g_testStack.replaceOnHandlerQueryFailure) {
                g_testStack.current = (stack_t) { .ss_sp = g_replacementStack,
                    .ss_size = sizeof(g_replacementStack) };
            }
#        endif
            errno = EINVAL;
            return -1;
        }
        *previous = g_testSignals.actions[signal];
    }
    if (action == NULL) {
        return 0;
    }
    g_testSignals.writeCalls++;
    const bool installing = action->sa_sigaction == sentrykscrash_managedSignalHandler;
    if (installing && signal == g_testSignals.installFailureSignal) {
        errno = EINVAL;
        return -1;
    }
    if (installing) {
        g_testSignals.installCalls++;
        g_testSignals.enabledDuringInstall |= sentrykscrash_managedSignalIsEnabled(NULL);
    }
    const bool deliver = installing && g_testSignals.installCalls == g_testSignals.deliverOnInstall;
    if (deliver && g_testSignals.deliverBeforeInstall) {
        // Another thread can enter an already-installed anchor while this sigaction is in flight.
        testDeliverSignal(kssignal_fatalSignals()[0]);
    }
    const bool restoring
        = !installing && action->sa_sigaction != sentrykscrash_managedSignalHandler;
    const bool deliverDuringRestore = restoring && !g_testSignals.deliveringDuringRestore
        && g_testSignals.nestedSignal != 0
        && ++g_testSignals.restoreWriteCalls == g_testSignals.deliverOnRestoreWrite;
    if (deliverDuringRestore && g_testSignals.deliverBeforeRestoreWrite) {
        g_testSignals.deliveringDuringRestore = true;
        testDeliverSignal(g_testSignals.nestedSignal);
        g_testSignals.deliveringDuringRestore = false;
    }
    g_testSignals.actions[signal] = *action;
    if (deliverDuringRestore && !g_testSignals.deliverBeforeRestoreWrite) {
        g_testSignals.deliveringDuringRestore = true;
        testDeliverSignal(g_testSignals.nestedSignal);
        g_testSignals.deliveringDuringRestore = false;
    }
    if (deliver && !g_testSignals.deliverBeforeInstall) {
        testDeliverSignal(signal);
    }
    return 0;
}

#        if SENTRY_HAS_SIGNAL_STACK
static int
testSigaltstack(const stack_t *stack, stack_t *previous)
{
    if (g_testStack.useSystemStack) {
        return sigaltstack(stack, previous);
    }
    if (previous != NULL) {
        if (++g_testStack.queries == g_testStack.failQueryOnCall) {
            errno = EINVAL;
            return -1;
        }
        *previous = g_testStack.current;
    }
    if (stack != NULL) {
        g_testStack.writes++;
        g_testStack.writesInHandler += g_testSignals.handlingSignal;
        // Darwin validates ss_size even for SS_DISABLE, unlike the usual POSIX expectation.
        if (stack->ss_size < MINSIGSTKSZ) {
            errno = ENOMEM;
            return -1;
        }
        if ((g_testStack.current.ss_flags & SS_ONSTACK)
            || ((stack->ss_flags & SS_DISABLE) ? g_testStack.failDisable
                                               : g_testStack.failRegistration)) {
            errno = EPERM;
            return -1;
        }
        g_testStack.current = *stack;
    }
    return 0;
}
#        endif

static int
testRaise(int signal)
{
    g_testSignals.raiseCalls++;
    g_testSignals.raisedSignal = signal;
    if (g_testSignals.deliveringDuringRestore) {
        g_testSignals.nestedRaiseCalls++;
        memcpy(g_testSignals.actionsAtNestedRaise, g_testSignals.actions,
            sizeof(g_testSignals.actions));
    } else {
        memcpy(g_testSignals.actionsAtRaise, g_testSignals.actions, sizeof(g_testSignals.actions));
    }
    return 0;
}

#        if SENTRY_HAS_SIGNAL_STACK
typedef struct {
    bool borrowHostStack;
    bool enabled;
    stack_t before;
    stack_t initial;
    stack_t after;
    int queryBeforeResult;
    int prepareResult;
    int queryInitialResult;
    int queryAfterResult;
    int restoreResult;
} RealStackProbe;

static void *
probeRealStack(void *value)
{
    RealStackProbe *probe = value;
    probe->queryBeforeResult = sigaltstack(NULL, &probe->before);
    if (probe->queryBeforeResult != 0) {
        return NULL;
    }
    // Sanitizers may provision a stack before pthread's entry point. Establish the requested
    // initial state explicitly, and restore the sanitizer/host's original registration afterward.
    stack_t initial = probe->borrowHostStack
        ? (stack_t) { .ss_sp = g_hostStack, .ss_size = sizeof(g_hostStack) }
        : (stack_t) { .ss_flags = SS_DISABLE, .ss_size = SIGSTKSZ };
    probe->prepareResult = sigaltstack(&initial, NULL);
    if (probe->prepareResult != 0) {
        return NULL;
    }
    probe->queryInitialResult = sigaltstack(NULL, &probe->initial);
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    probe->enabled = sentrykscrash_managedSignalIsEnabled(NULL);
    probe->queryAfterResult = sigaltstack(NULL, &probe->after);
    stack_t restore = probe->before;
    if ((restore.ss_flags & SS_DISABLE) && restore.ss_size < MINSIGSTKSZ) {
        restore.ss_size = MINSIGSTKSZ;
    }
    probe->restoreResult = sigaltstack(&restore, NULL);
    return NULL;
}
#        endif

typedef struct {
    int signalToRegister;
    int signalToConsume;
    bool shouldConsume;
    bool consumed;
    uintptr_t registeredThread;
    SentryIgnoredSignal *entry;
} IgnoredSignalWorker;

static void *
exerciseIgnoredSignalOnWorker(void *value)
{
    IgnoredSignalWorker *worker = value;
    if (worker->signalToRegister != 0) {
        test_ignoreNextSignal(worker->signalToRegister);
        worker->entry = pthread_getspecific(g_ignoredSignalKey);
        if (worker->entry != NULL) {
            worker->registeredThread
                = atomic_load_explicit(&worker->entry->thread, memory_order_relaxed);
        }
    }
    if (worker->shouldConsume) {
        worker->consumed = sentrykscrash_consumeIgnoredSignal(worker->signalToConsume);
    }
    return NULL;
}

@interface SentryKSCrashManagedSignalTests : XCTestCase
@end

@implementation SentryKSCrashManagedSignalTests

- (void)setUp
{
    [super setUp];
    memset(&g_managedSignal, 0, sizeof(g_managedSignal));
    memset(&g_testSignals, 0, sizeof(g_testSignals));
    memset(&g_testAllocations, 0, sizeof(g_testAllocations));
    memset(&g_testCallbacks, 0, sizeof(g_testCallbacks));
#        if SENTRY_HAS_SIGNAL_STACK
    memset(&g_testStack, 0, sizeof(g_testStack));
    g_testStack.current.ss_flags = SS_DISABLE;
#        endif
    for (int i = 0; i < kssignal_numFatalSignals(); i++) {
        const int signal = kssignal_fatalSignals()[i];
        struct sigaction action = { 0 };
        action.sa_handler = previousHandler;
        action.sa_flags = SA_RESTART;
        sigemptyset(&action.sa_mask);
        sigaddset(&action.sa_mask, SIGUSR1);
        g_testSignals.originals[signal] = action;
        g_testSignals.actions[signal] = action;
    }
}

- (void)tearDown
{
    XCTAssertEqual(g_testAllocations.invalidFrees, 0);
    XCTAssertEqual(g_testAllocations.freesInHandler, 0);
    if (g_ignoredSignalKeyCreated) {
        XCTAssertEqual(pthread_setspecific(g_ignoredSignalKey, NULL), 0);
    }
    atomic_store_explicit(&g_ignoredSignals, NULL, memory_order_release);
#        if SENTRY_HAS_SIGNAL_STACK
    XCTAssertEqual(g_testStack.writesInHandler, 0);
#        endif
    // All syscalls are fake and synchronous. Reclaim even intentionally retained allocations so
    // each test starts with isolated state, without relying on production's ownership bookkeeping.
    for (size_t i = 0; i < g_testAllocations.count; i++) {
        if (g_testAllocations.entries[i].live) {
            free(g_testAllocations.entries[i].pointer);
        }
    }
    [super tearDown];
}

- (void)assertOriginalHandlers:(const struct sigaction *)actions
{
    for (int i = 0; i < kssignal_numFatalSignals(); i++) {
        const int signal = kssignal_fatalSignals()[i];
        XCTAssertEqual(actions[signal].sa_handler, g_testSignals.originals[signal].sa_handler,
            @"predecessor for signal %d", signal);
        XCTAssertEqual(actions[signal].sa_flags, g_testSignals.originals[signal].sa_flags,
            @"flags for signal %d", signal);
        XCTAssertEqual(actions[signal].sa_mask, g_testSignals.originals[signal].sa_mask,
            @"mask for signal %d", signal);
    }
}

- (void)testInstall_whenSignalArrivesAfterFirstHandler_shouldRestoreOnlyCapturedPredecessors
{
    // -- Arrange --
    g_testSignals.deliverOnInstall = 1;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    XCTAssertEqual(g_testSignals.raisedSignal, kssignal_fatalSignals()[0]);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testSignals.installCalls, 1);
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInstall_whenSignalArrivesAfterLastHandler_shouldNotPublishInstalled
{
    // -- Arrange --
    g_testSignals.deliverOnInstall = kssignal_numFatalSignals();

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInstall_whenSignalArrivesDuringSigaction_shouldRollBackInFlightHandler
{
    // -- Arrange --
    g_testSignals.deliverOnInstall = 2;
    g_testSignals.deliverBeforeInstall = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testSignals.installCalls, 2);
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)
    testHandler_whenSecondSignalArrivesBetweenRestoreWrites_shouldRestoreItsPredecessorBeforeReraise
{
    // -- Arrange --
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    g_testSignals.deliverOnRestoreWrite = 1;
    g_testSignals.nestedSignal = kssignal_fatalSignals()[1];

    // -- Act --
    testDeliverSignal(kssignal_fatalSignals()[0]);

    // -- Assert --
    XCTAssertEqual(g_testSignals.nestedRaiseCalls, 1);
    const int nestedSignal = g_testSignals.nestedSignal;
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_handler,
        g_testSignals.originals[nestedSignal].sa_handler);
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_flags,
        g_testSignals.originals[nestedSignal].sa_flags);
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_mask,
        g_testSignals.originals[nestedSignal].sa_mask);
}

- (void)testHandler_whenOwnPredecessorRestoreIsInFlight_shouldRestoreItBeforeReraise
{
    // -- Arrange --
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    g_testSignals.deliverOnRestoreWrite = 1;
    g_testSignals.deliverBeforeRestoreWrite = true;
    g_testSignals.nestedSignal = kssignal_fatalSignals()[0];

    // -- Act --
    testDeliverSignal(kssignal_fatalSignals()[1]);

    // -- Assert --
    XCTAssertEqual(g_testSignals.nestedRaiseCalls, 1);
    const int nestedSignal = g_testSignals.nestedSignal;
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_handler,
        g_testSignals.originals[nestedSignal].sa_handler);
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_flags,
        g_testSignals.originals[nestedSignal].sa_flags);
    XCTAssertEqual(g_testSignals.actionsAtNestedRaise[nestedSignal].sa_mask,
        g_testSignals.originals[nestedSignal].sa_mask);
}

- (void)testInstall_whenSuccessful_shouldPublishEnabledOnlyAfterAllHandlersAreInstalled
{
    // -- Arrange --
    KSCrashMonitorAPI *api = test_managedSignalMonitorAPI();

    // -- Act --
    api->setEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(g_testSignals.enabledDuringInstall);
    XCTAssertTrue(api->isEnabled(NULL));
    XCTAssertEqual(g_testSignals.installCalls, kssignal_numFatalSignals());
    for (int i = 0; i < kssignal_numFatalSignals(); i++) {
        XCTAssertEqual(g_testSignals.actions[kssignal_fatalSignals()[i]].sa_sigaction,
            &sentrykscrash_managedSignalHandler);
    }
}

- (void)testInstall_whenQueryFails_shouldPreserveAllPredecessors
{
    // -- Arrange --
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[1];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInstall_whenHandlerInstallFails_shouldRollBackAndPreserveAllPredecessors
{
    // -- Arrange --
    g_testSignals.installFailureSignal = kssignal_fatalSignals()[1];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testSignals.installCalls, 1);
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInstall_whenSignalIsIgnored_shouldLeaveItIgnoredDuringInstallAndRestore
{
    // -- Arrange --
    const int signal = kssignal_fatalSignals()[1];
    g_testSignals.originals[signal].sa_handler = SIG_IGN;
    g_testSignals.actions[signal] = g_testSignals.originals[signal];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    const struct sigaction ignoredAction = g_testSignals.actions[signal];
    sentrykscrash_managedSignalRestoreHandlers();

    // -- Assert --
    XCTAssertEqual(ignoredAction.sa_handler, SIG_IGN);
    XCTAssertEqual(g_testSignals.installCalls, kssignal_numFatalSignals() - 1);
    [self assertOriginalHandlers:g_testSignals.actions];
}

- (void)testSetEnabled_whenToggledAfterPreinstall_shouldAdoptWithoutReplacingHandlers
{
    // -- Arrange --
    sentrykscrash_managedSignalInstall();
    const int writeCalls = g_testSignals.writeCalls;
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    KSCrashMonitorAPI *api = test_managedSignalMonitorAPI();

    // -- Act --
    api->init(&callbacks, NULL);
    api->setEnabled(true, NULL);
    api->setEnabled(false, NULL);
    api->setEnabled(true, NULL);

    // -- Assert --
    XCTAssertTrue(api->isEnabled(NULL));
    XCTAssertEqual(g_testSignals.writeCalls, writeCalls);
}

#        pragma mark - Build and plugin policy

- (void)testBuildPolicy_whenCompiledWithoutManagedRuntimeFlag_shouldUseOrdinaryKSCrashPath
{
    // -- Act --
    const bool managed = test_isManagedRuntimeBuild();

    // -- Assert --
    XCTAssertFalse(managed);
}

- (void)testManagedMachExceptionMask_shouldLeaveManagedFaultsToSignalLayer
{
    // -- Act --
    const uint32_t mask = test_managedMachExceptionMask();

    // -- Assert --
#        if defined(__APPLE__)
    XCTAssertEqual(
        mask, (uint32_t)(EXC_MASK_BAD_INSTRUCTION | EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT));
    XCTAssertEqual(mask & EXC_MASK_BAD_ACCESS, 0u);
    XCTAssertEqual(mask & EXC_MASK_ARITHMETIC, 0u);
#        else
    XCTAssertEqual(mask, 0u);
#        endif
}

- (void)testManagedSignalMonitorAPI_shouldExposeStandardSignalIdentityAndPluginFlags
{
    // -- Arrange --
    KSCrashMonitorAPI *api = test_managedSignalMonitorAPI();

    // -- Act --
    const char *monitorId = api->monitorId(NULL);
    const KSCrashMonitorFlag flags = api->monitorFlags(NULL);

    // -- Assert --
    XCTAssertEqual(strcmp(monitorId, "Signal"), 0);
    XCTAssertEqual(flags, KSCrashMonitorFlagAsyncSafe | KSCrashMonitorFlagPlugin);
}

#        pragma mark - One-shot signal suppression

- (void)testIgnoreNextSignal_whenSignalMatches_shouldConsumeOnlyOnce
{
    // -- Arrange --
    test_ignoreNextSignal(SIGSEGV);

    // -- Act --
    const bool first = sentrykscrash_consumeIgnoredSignal(SIGSEGV);
    const bool second = sentrykscrash_consumeIgnoredSignal(SIGSEGV);

    // -- Assert --
    XCTAssertTrue(first);
    XCTAssertFalse(second);
}

- (void)testIgnoreNextSignal_whenSignalMismatches_shouldConsumeTokenWithoutSuppressingLaterMatch
{
    // -- Arrange --
    test_ignoreNextSignal(SIGSEGV);

    // -- Act --
    const bool mismatch = sentrykscrash_consumeIgnoredSignal(SIGABRT);
    const bool laterMatch = sentrykscrash_consumeIgnoredSignal(SIGSEGV);

    // -- Assert --
    XCTAssertFalse(mismatch);
    XCTAssertFalse(laterMatch);
}

- (void)testIgnoreNextSignal_whenRepeatedOnSameThread_shouldReplacePendingSignal
{
    // -- Arrange --
    test_ignoreNextSignal(SIGSEGV);

    // -- Act --
    test_ignoreNextSignal(SIGABRT);
    const bool oldSignal = sentrykscrash_consumeIgnoredSignal(SIGSEGV);
    test_ignoreNextSignal(SIGABRT);
    const bool replacementSignal = sentrykscrash_consumeIgnoredSignal(SIGABRT);

    // -- Assert --
    XCTAssertFalse(oldSignal);
    XCTAssertTrue(replacementSignal);
    XCTAssertEqual(g_testAllocations.count, 1u);
}

- (void)testIgnoreNextSignal_whenAnotherThreadReceivesSignal_shouldKeepCallingThreadToken
{
    // -- Arrange --
    test_ignoreNextSignal(SIGSEGV);
    IgnoredSignalWorker worker = { .signalToConsume = SIGSEGV, .shouldConsume = true };
    pthread_t thread;

    // -- Act --
    const int createResult = pthread_create(&thread, NULL, exerciseIgnoredSignalOnWorker, &worker);
    XCTAssertEqual(createResult, 0);
    if (createResult == 0) {
        XCTAssertEqual(pthread_join(thread, NULL), 0);
    }
    const bool callingThreadConsumed = sentrykscrash_consumeIgnoredSignal(SIGSEGV);

    // -- Assert --
    XCTAssertFalse(worker.consumed);
    XCTAssertTrue(callingThreadConsumed);
}

- (void)testIgnoreNextSignal_whenRegisteringThreadExits_shouldClearRetainedIdentity
{
    // -- Arrange --
    IgnoredSignalWorker registeringWorker = { .signalToRegister = SIGSEGV };
    pthread_t registeringThread;

    // -- Act --
    const int createResult = pthread_create(
        &registeringThread, NULL, exerciseIgnoredSignalOnWorker, &registeringWorker);
    XCTAssertEqual(createResult, 0);
    if (createResult == 0) {
        XCTAssertEqual(pthread_join(registeringThread, NULL), 0);
    }

    // -- Assert --
    XCTAssertNotEqual(registeringWorker.entry, NULL);
    XCTAssertNotEqual(registeringWorker.registeredThread, (uintptr_t)0);
    if (registeringWorker.entry != NULL) {
        XCTAssertEqual(atomic_load_explicit(&registeringWorker.entry->thread, memory_order_relaxed),
            (uintptr_t)0);
        XCTAssertEqual(
            atomic_load_explicit(&registeringWorker.entry->signal, memory_order_relaxed), 0);
    }

    IgnoredSignalWorker laterWorker = { .signalToConsume = SIGSEGV, .shouldConsume = true };
    pthread_t laterThread;
    const int laterCreateResult
        = pthread_create(&laterThread, NULL, exerciseIgnoredSignalOnWorker, &laterWorker);
    XCTAssertEqual(laterCreateResult, 0);
    if (laterCreateResult == 0) {
        XCTAssertEqual(pthread_join(laterThread, NULL), 0);
    }
    XCTAssertFalse(laterWorker.consumed);
}

#        pragma mark - Callback publication

- (void)testInit_whenNull_shouldRemainUnpublished
{
    // -- Act --
    sentrykscrash_managedSignalInit(NULL, NULL);

    // -- Assert --
    XCTAssertFalse(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 0);
    XCTAssertEqual(g_testSignals.writeCalls, 0);
}

- (void)testInit_whenNotifyMissing_shouldRejectAndAllowValidRetry
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks incomplete = { .handle = testHandleA };
    KSCrash_ExceptionHandlerCallbacks valid = testCallbacksA();

    // -- Act --
    sentrykscrash_managedSignalInit(&incomplete, NULL);
    const bool incompletePublished = atomic_load(&g_managedSignal.callbacksReady);
    sentrykscrash_managedSignalInit(&valid, NULL);

    // -- Assert --
    XCTAssertFalse(incompletePublished);
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(g_managedSignal.callbacks.notify, &testNotifyA);
    XCTAssertEqual(g_managedSignal.callbacks.handle, &testHandleA);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testInit_whenHandleMissing_shouldRejectAndAllowValidRetry
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks incomplete = { .notify = testNotifyA };
    KSCrash_ExceptionHandlerCallbacks valid = testCallbacksA();

    // -- Act --
    sentrykscrash_managedSignalInit(&incomplete, NULL);
    const bool incompletePublished = atomic_load(&g_managedSignal.callbacksReady);
    sentrykscrash_managedSignalInit(&valid, NULL);

    // -- Assert --
    XCTAssertFalse(incompletePublished);
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(g_managedSignal.callbacks.notify, &testNotifyA);
    XCTAssertEqual(g_managedSignal.callbacks.handle, &testHandleA);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testInit_whenValid_shouldCopyCallbacksWithoutInstallingOrActivating
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();

    // -- Act --
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    callbacks = testCallbacksB();

    // -- Assert --
    XCTAssertEqual(callbacks.notify, &testNotifyB);
    XCTAssertEqual(g_managedSignal.callbacks.notify, &testNotifyA);
    XCTAssertEqual(g_managedSignal.callbacks.handle, &testHandleA);
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(atomic_load(&g_managedSignal.installedState), SentryManagedSignalNotInstalled);
    XCTAssertEqual(g_testSignals.writeCalls, 0);
    XCTAssertEqual(g_testAllocations.count, 0u);
}

- (void)testInit_whenRepeatedWithSameTable_shouldPublishOnlyOnce
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    const int writes = g_testSignals.writeCalls;

    // -- Act --
    sentrykscrash_managedSignalInit(&callbacks, NULL);

    // -- Assert --
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
    XCTAssertEqual(g_testSignals.writeCalls, writes);
    XCTAssertTrue(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInit_whenRepeatedWithInvalidTable_shouldKeepPublishedCallbacks
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    KSCrash_ExceptionHandlerCallbacks incomplete = { 0 };

    // -- Act --
    sentrykscrash_managedSignalInit(&incomplete, NULL);
    sentrykscrash_managedSignalInit(NULL, NULL);

    // -- Assert --
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(g_managedSignal.callbacks.notify, &testNotifyA);
    XCTAssertEqual(g_managedSignal.callbacks.handle, &testHandleA);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testInit_whenRepeatedWithDifferentTable_shouldKeepFirstValidPair
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    KSCrash_ExceptionHandlerCallbacks replacement = testCallbacksB();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Act --
    sentrykscrash_managedSignalInit(&replacement, NULL);
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.handleA, 1);
    XCTAssertEqual(g_testCallbacks.notifyB, 0);
    XCTAssertEqual(g_testCallbacks.handleB, 0);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testInit_whenReenteredDuringNotify_shouldNotSwitchHandleMidReport
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    g_testCallbacks.reinitializeDuringNotify = true;

    // -- Act --
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.handleA, 1);
    XCTAssertEqual(g_testCallbacks.handleB, 0);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testInit_whenConcurrent_shouldPublishExactlyOneCompletePair
{
    // -- Arrange --
    CallbackInitGate gate
        = { .mutex = PTHREAD_MUTEX_INITIALIZER, .condition = PTHREAD_COND_INITIALIZER };
    CallbackInitWorker workers[] = {
        { .gate = &gate, .callbacks = testCallbacksA() },
        { .gate = &gate, .callbacks = testCallbacksB() },
    };
    pthread_t threads[2];
    size_t created = 0;

    // -- Act --
    for (; created < 2; created++) {
        const int result = pthread_create(
            &threads[created], NULL, initializeCallbacksConcurrently, &workers[created]);
        XCTAssertEqual(result, 0);
        if (result != 0) {
            break;
        }
    }
    // Unlike a tiny dispatch_apply body, this guarantees two distinct contenders are ready.
    // The gate is test-only and unlocked before init; SDK initialization never waits on a lock.
    pthread_mutex_lock(&gate.mutex);
    while (gate.arrived < created) {
        pthread_cond_wait(&gate.condition, &gate.mutex);
    }
    gate.start = true;
    pthread_cond_broadcast(&gate.condition);
    pthread_mutex_unlock(&gate.mutex);
    for (size_t i = 0; i < created; i++) {
        XCTAssertEqual(pthread_join(threads[i], NULL), 0);
    }
    pthread_cond_destroy(&gate.condition);
    pthread_mutex_destroy(&gate.mutex);

    // -- Assert --
    XCTAssertEqual(created, 2u);
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
    XCTAssertTrue((g_managedSignal.callbacks.notify == testNotifyA
                      && g_managedSignal.callbacks.handle == testHandleA)
        || (g_managedSignal.callbacks.notify == testNotifyB
            && g_managedSignal.callbacks.handle == testHandleB));
    XCTAssertEqual(g_testSignals.writeCalls, 0);
    XCTAssertEqual(g_testAllocations.count, 0u);
}

- (void)testInit_whenSignalArrivesBeforePublication_shouldForwardWithoutCallingCallbacks
{
    // -- Arrange --
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    g_testCallbacks.deliverBeforePublication = true;

    // -- Act --
    sentrykscrash_managedSignalInit(&callbacks, NULL);

    // -- Assert --
    XCTAssertFalse(g_testCallbacks.deliverBeforePublication); // The boundary was exercised.
    XCTAssertEqual(g_testCallbacks.notifyA, 0);
    XCTAssertEqual(g_testCallbacks.handleA, 0);
    XCTAssertEqual(g_testCallbacks.contextCalls, 0);
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
}

- (void)testInit_whenReenteredBeforePublication_shouldKeepPendingPairWithoutPublishingEarly
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    g_testCallbacks.reinitializeBeforePublication = true;

    // -- Act --
    sentrykscrash_managedSignalInit(&callbacks, NULL);

    // -- Assert --
    XCTAssertFalse(g_testCallbacks.reinitializeBeforePublication);
    XCTAssertFalse(g_testCallbacks.readyAfterReinitialization);
    XCTAssertTrue(atomic_load(&g_managedSignal.callbacksReady));
    XCTAssertEqual(g_managedSignal.callbacks.notify, &testNotifyA);
    XCTAssertEqual(g_managedSignal.callbacks.handle, &testHandleA);
    XCTAssertEqual(atomic_load(&g_testCallbacks.publications), 1);
}

- (void)testHandler_whenEnabledBeforeInitialization_shouldOnlyForward
{
    // -- Arrange --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Act --
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 0);
    XCTAssertEqual(g_testCallbacks.contextCalls, 0);
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
}

- (void)testHandler_whenCallbacksReady_shouldNotifyFillContextAndHandleBeforeForwarding
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Act --
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.handleA, 1);
    XCTAssertEqual(g_testCallbacks.contextCalls, 1);
    XCTAssertEqual(g_testCallbacks.unwindCalls, 1);
    XCTAssertTrue(g_testCallbacks.requirements.asyncSafety);
    XCTAssertTrue(g_testCallbacks.requirements.isFatal);
    XCTAssertTrue(g_testCallbacks.requirements.shouldWriteReport);
    XCTAssertTrue(g_testCallbacks.requirements.shouldRecordAllThreads);
    XCTAssertEqual(g_testCallbacks.reportedSignal, SIGSEGV);
    XCTAssertTrue(g_testCallbacks.reportedSignalMonitor);
    XCTAssertTrue(g_testCallbacks.reportedMachineContext);
    XCTAssertTrue(g_testCallbacks.reportedStackCursor);
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
}

- (void)testHandler_whenNotifyReturnsNull_shouldForwardWithoutFillingOrHandling
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    g_testCallbacks.returnNull = true;

    // -- Act --
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.contextCalls, 0);
    XCTAssertEqual(g_testCallbacks.handleA, 0);
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
}

- (void)testHandler_whenNotifyRequestsImmediateExit_shouldForwardWithoutFillingOrHandling
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    g_testCallbacks.context.requirements.shouldExitImmediately = true;

    // -- Act --
    testDeliverSignal(SIGSEGV);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.contextCalls, 0);
    XCTAssertEqual(g_testCallbacks.handleA, 0);
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actionsAtRaise];
}

- (void)testHandler_whenSigterm_shouldRequestCleanExitWithoutReport
{
    // -- Arrange --
    KSCrash_ExceptionHandlerCallbacks callbacks = testCallbacksA();
    sentrykscrash_managedSignalInit(&callbacks, NULL);
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Act --
    testDeliverSignal(SIGTERM);

    // -- Assert --
    XCTAssertEqual(g_testCallbacks.notifyA, 1);
    XCTAssertEqual(g_testCallbacks.handleA, 1);
    XCTAssertTrue(g_testCallbacks.requirements.isFatal);
    XCTAssertTrue(g_testCallbacks.requirements.isCleanExit);
    XCTAssertFalse(g_testCallbacks.requirements.shouldWriteReport);
    XCTAssertFalse(g_testCallbacks.requirements.shouldRecordAllThreads);
    XCTAssertEqual(g_testSignals.raisedSignal, SIGTERM);
}

#        if SENTRY_HAS_SIGNAL_STACK

- (void)exerciseRealStack:(RealStackProbe *)probe
{
    // Only this short-lived worker's alternate stack is real. Signal dispositions stay fake,
    // and the worker restores its original stack before joining and test allocation cleanup.
    g_testStack.useSystemStack = true;
    pthread_t thread;
    const int createResult = pthread_create(&thread, NULL, probeRealStack, probe);
    XCTAssertEqual(createResult, 0);
    if (createResult != 0) {
        return;
    }
    XCTAssertEqual(pthread_join(thread, NULL), 0);
    XCTAssertEqual(probe->queryBeforeResult, 0);
    XCTAssertEqual(probe->prepareResult, 0);
    XCTAssertEqual(probe->queryInitialResult, 0);
    XCTAssertEqual(probe->queryAfterResult, 0);
    XCTAssertEqual(probe->restoreResult, 0);
}

- (void)testInstall_whenRealWorkerHasHostStack_shouldPreserveKernelRegistration
{
    // -- Arrange --
    RealStackProbe probe = { .borrowHostStack = true };

    // -- Act --
    [self exerciseRealStack:&probe];

    // -- Assert --
    XCTAssertTrue(probe.enabled);
    XCTAssertEqual(probe.after.ss_sp, (void *)g_hostStack);
    XCTAssertEqual(probe.after.ss_size, sizeof(g_hostStack));
    XCTAssertEqual(probe.after.ss_flags, 0);
    XCTAssertEqual(liveAllocations(), 1u);
}

- (void)testInstall_whenRealWorkerHasNoStack_shouldRegisterOwnedStackWithKernel
{
    // -- Arrange --
    RealStackProbe probe = { 0 };

    // -- Act --
    [self exerciseRealStack:&probe];

    // -- Assert --
    XCTAssertTrue(probe.initial.ss_flags & SS_DISABLE);
    XCTAssertTrue(probe.enabled);
    XCTAssertEqual(probe.after.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(probe.after.ss_size, (size_t)SIGSTKSZ);
    XCTAssertEqual(probe.after.ss_flags, 0);
    XCTAssertEqual(liveAllocations(), 2u);
}

- (void)testInstall_whenEarlyFailureOnRealWorker_shouldDetachStackBeforeFreeing
{
    // -- Arrange --
    RealStackProbe probe = { 0 };
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];

    // -- Act --
    [self exerciseRealStack:&probe];

    // -- Assert --
    XCTAssertTrue(probe.initial.ss_flags & SS_DISABLE);
    XCTAssertFalse(probe.enabled);
    XCTAssertTrue(probe.after.ss_flags & SS_DISABLE);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenHostStackExists_shouldBorrowItWithoutReplacingOrAllocating
{
    // -- Arrange --
    g_testStack.current = (stack_t) { .ss_sp = g_hostStack, .ss_size = sizeof(g_hostStack) };

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertTrue(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, (void *)g_hostStack);
    XCTAssertEqual(g_testStack.current.ss_size, sizeof(g_hostStack));
    XCTAssertEqual(g_testStack.writes, 0);
    XCTAssertEqual(liveAllocations(), 1u); // Predecessor table only.
}

- (void)testInstall_whenAlreadyOnHostStack_shouldNotTryToReplaceIt
{
    // -- Arrange --
    g_testStack.current = (stack_t) {
        .ss_sp = g_hostStack, .ss_size = sizeof(g_hostStack), .ss_flags = SS_ONSTACK
    };

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertTrue(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, (void *)g_hostStack);
    XCTAssertEqual(g_testStack.current.ss_flags, SS_ONSTACK);
    XCTAssertEqual(g_testStack.writes, 0);
    XCTAssertEqual(liveAllocations(), 1u);
}

- (void)testInstall_whenStackDisabled_shouldRegisterOwnedStackAndRetainItAcrossDisable
{
    // -- Arrange --
    XCTAssertEqual(g_testStack.current.ss_flags, SS_DISABLE);

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);
    sentrykscrash_managedSignalSetEnabled(false, NULL);

    // -- Assert --
    XCTAssertNotEqual(g_testStack.current.ss_sp, NULL);
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(g_testStack.current.ss_size, (size_t)SIGSTKSZ);
    XCTAssertEqual(g_testStack.current.ss_flags, 0);
    XCTAssertEqual(g_testStack.writes, 1);
    XCTAssertEqual(liveAllocations(), 2u);
}

- (void)testInstall_whenStackQueryFails_shouldFailWithoutChangingHandlersOrStack
{
    // -- Arrange --
    g_testStack.failQueryOnCall = 1;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.writes, 0);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenStackAllocationFails_shouldReleaseUnusedResources
{
    // -- Arrange --
    g_testAllocations.failMalloc = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.writes, 0);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenStackRegistrationFails_shouldReleaseUnregisteredAllocation
{
    // -- Arrange --
    g_testStack.failRegistration = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.current.ss_flags, SS_DISABLE);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenPredecessorAllocationFails_shouldLeaveNoOwnedResources
{
    // -- Arrange --
    g_testAllocations.failCalloc = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.current.ss_flags, SS_DISABLE);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenFirstHandlerQueryFails_shouldDetachAndReleaseUnusedStack
{
    // -- Arrange --
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.current.ss_flags, SS_DISABLE);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenFirstHandlerWriteFails_shouldDetachAndReleaseUnusedStack
{
    // -- Arrange --
    g_testSignals.installFailureSignal = kssignal_fatalSignals()[0];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.current.ss_flags, SS_DISABLE);
    XCTAssertEqual(liveAllocations(), 0u);
}

- (void)testInstall_whenLaterHandlerWriteFails_shouldRetainPotentiallyReferencedResources
{
    // -- Arrange --
    g_testSignals.installFailureSignal = kssignal_fatalSignals()[1];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(g_testStack.current.ss_flags, 0);
    XCTAssertEqual(liveAllocations(), 2u);
}

- (void)testInstall_whenInterruptedOnOwnedStack_shouldRetainStackAndPredecessors
{
    // -- Arrange --
    g_testSignals.deliverOnInstall = 1;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.writes, 1);
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(liveAllocations(), 2u);
}

- (void)testHandler_whenOnOwnedStack_shouldRestoreHandlersWithoutDetachingOrFreeingStack
{
    // -- Arrange --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Act --
    testDeliverSignal(kssignal_fatalSignals()[0]);

    // -- Assert --
    XCTAssertEqual(g_testSignals.raiseCalls, 1);
    [self assertOriginalHandlers:g_testSignals.actions];
    XCTAssertEqual(g_testStack.writes, 1);
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(liveAllocations(), 2u);
}

- (void)testInstall_whenRollbackCannotDetachStack_shouldRetainRegisteredAllocation
{
    // -- Arrange --
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];
    g_testStack.failDisable = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(g_testStack.current.ss_flags, 0);
    XCTAssertEqual(liveAllocations(), 1u); // Still registered, but the unused table is released.
}

- (void)testInstall_whenRollbackCannotQueryStack_shouldRetainPossiblyRegisteredAllocation
{
    // -- Arrange --
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];
    g_testStack.failQueryOnCall = 2;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, g_managedSignal.signalStack.ss_sp);
    XCTAssertEqual(liveAllocations(), 1u);
}

- (void)testInstall_whenAnotherOwnerReplacesStackBeforeEarlyFailure_shouldLeaveReplacementAlone
{
    // -- Arrange --
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];
    g_testStack.replaceOnHandlerQueryFailure = true;

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, (void *)g_replacementStack);
    XCTAssertEqual(g_testStack.current.ss_size, sizeof(g_replacementStack));
    XCTAssertEqual(g_testStack.current.ss_flags, 0);
    // A replacement owner might retain a pointer to the old buffer. Reclaim only the table.
    XCTAssertEqual(liveAllocations(), 1u);
}

- (void)testInstall_whenEarlyFailureWithBorrowedStack_shouldNeverFreeOrDisableHostStack
{
    // -- Arrange --
    g_testStack.current = (stack_t) { .ss_sp = g_hostStack, .ss_size = sizeof(g_hostStack) };
    g_testSignals.queryFailureSignal = kssignal_fatalSignals()[0];

    // -- Act --
    sentrykscrash_managedSignalSetEnabled(true, NULL);

    // -- Assert --
    XCTAssertFalse(sentrykscrash_managedSignalIsEnabled(NULL));
    XCTAssertEqual(g_testStack.current.ss_sp, (void *)g_hostStack);
    XCTAssertEqual(g_testStack.writes, 0);
    XCTAssertEqual(liveAllocations(), 0u);
}

#        endif // SENTRY_HAS_SIGNAL_STACK

@end

#    endif // SENTRY_HAS_SIGNAL
#endif // SDK_V10
