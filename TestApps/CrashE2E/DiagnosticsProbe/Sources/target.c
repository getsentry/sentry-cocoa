#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <unistd.h>

static void *
heartbeat(void *unused)
{
    (void)unused;
    for (;;) {
        puts("heartbeat");
        fflush(stdout);
        usleep(50000);
    }
    return NULL;
}

// A named, blocked frame makes the probe check actual stack content, not just file existence.
__attribute__((noinline)) static int
crash_e2e_probe_wait(sigset_t *signals)
{
    int received = 0;
    return sigwait(signals, &received);
}

int
main(void)
{
    sigset_t signals;
    sigemptyset(&signals);
    sigaddset(&signals, SIGTERM);
    if (pthread_sigmask(SIG_BLOCK, &signals, NULL) != 0) {
        return 1;
    }
    pthread_t thread;
    if (pthread_create(&thread, NULL, heartbeat, NULL) != 0) {
        return 2;
    }
    // Exiting requires the target to run sigwait; a pending SIGTERM alone is not success.
    return crash_e2e_probe_wait(&signals);
}
