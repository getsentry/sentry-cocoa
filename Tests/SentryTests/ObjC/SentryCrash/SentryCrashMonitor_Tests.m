#if !SDK_V10
// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashMonitor_Tests.m
//
//  Created by Karl Stenerud on 2013-03-09.
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

#    import <XCTest/XCTest.h>

#    import "SentryCrashMonitor.h"
#    import "SentryCrashMonitorContext.h"
#    import "SentryCrashMonitor_MachException.h"

#    import <mach/mach.h>
#    import <pthread.h>
#    import <signal.h>
#    import <stdatomic.h>

static _Atomic(mach_port_t) g_sigpipeReceiver = MACH_PORT_NULL;

static void
sentryCrashMonitorTests_recordSigpipeReceiver(int signum)
{
    (void)signum;
    atomic_store(&g_sigpipeReceiver, pthread_mach_thread_np(pthread_self()));
}

/** Returns the primary mach exception handler thread once it has started, or NULL. */
static pthread_t
sentryCrashMonitorTests_primaryExceptionHandlerThread(void)
{
    thread_act_array_t threads = NULL;
    mach_msg_type_number_t count = 0;
    if (task_threads(mach_task_self(), &threads, &count) != KERN_SUCCESS) {
        return NULL;
    }
    pthread_t primary = NULL;
    for (mach_msg_type_number_t i = 0; i < count; i++) {
        if (primary == NULL && sentrycrashcm_isReservedThread(threads[i])) {
            pthread_t thread = pthread_from_mach_thread_np(threads[i]);
            char name[64] = { 0 };
            if (thread != NULL && pthread_getname_np(thread, name, sizeof(name)) == 0
                && strcmp(name, "SentryCrash Exception Handler (Primary)") == 0) {
                primary = thread;
            }
        }
        mach_port_deallocate(mach_task_self(), threads[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threads, sizeof(thread_t) * count);
    return primary;
}

@interface SentryCrashMonitor_Tests : XCTestCase
@end

@implementation SentryCrashMonitor_Tests

- (void)testInstallUninstall
{
    sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeAll);
    sentrycrashcm_setActiveMonitors(SentryCrashMonitorTypeNone);
}

- (void)testSuspendResumeThreads
{
    thread_act_array_t threads1 = NULL;
    mach_msg_type_number_t numThreads1 = 0;
    sentrycrashmc_suspendEnvironment(&threads1, &numThreads1);

    thread_act_array_t threads2 = NULL;
    mach_msg_type_number_t numThreads2 = 0;
    sentrycrashmc_suspendEnvironment(&threads2, &numThreads2);

    sentrycrashmc_resumeEnvironment(threads2, numThreads2);
    sentrycrashmc_resumeEnvironment(threads1, numThreads1);
}

- (void)testMachExceptionHandlerThread_whenSIGPIPEIsSentToIt_shouldNotRunSignalHandler
{
    // -- Arrange --
    SentryCrashMonitorAPI *api = sentrycrashcm_machexception_getAPI();
    bool wasEnabled = api->isEnabled();
    api->setEnabled(true);

    // The thread names itself right before it blocks the signals, so wait for the name.
    pthread_t primary = NULL;
    for (int attempt = 0; attempt < 100 && primary == NULL; attempt++) {
        primary = sentryCrashMonitorTests_primaryExceptionHandlerThread();
        if (primary == NULL) {
            usleep(10 * 1000);
        }
    }
    if (primary == NULL) {
        api->setEnabled(wasEnabled);
        XCTFail(@"The primary mach exception handler thread did not start.");
        return;
    }
    usleep(50 * 1000);

    atomic_store(&g_sigpipeReceiver, MACH_PORT_NULL);
    struct sigaction action = { 0 };
    action.sa_handler = sentryCrashMonitorTests_recordSigpipeReceiver;
    sigemptyset(&action.sa_mask);
    struct sigaction previousAction = { 0 };
    XCTAssertEqual(sigaction(SIGPIPE, &action, &previousAction), 0);

    // -- Act --
    // A process-wide SIGPIPE cannot be aimed at one thread, so send it to the thread directly. A
    // thread that blocks SIGPIPE keeps it pending instead of running the handler, which is also
    // what makes the kernel deliver a process-wide SIGPIPE to another thread.
    XCTAssertEqual(pthread_kill(primary, SIGPIPE), 0);
    usleep(200 * 1000);

    // -- Assert --
    XCTAssertEqual(atomic_load(&g_sigpipeReceiver), (mach_port_t)MACH_PORT_NULL);

    XCTAssertEqual(sigaction(SIGPIPE, &previousAction, NULL), 0);
    api->setEnabled(wasEnabled);
}

@end

#endif // !SDK_V10
