#ifndef SentryKSCrashIgnoreNextSignal_h
#define SentryKSCrashIgnoreNextSignal_h

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Tell the crash reporter to ignore the next occurrence of the given signal on
 * the calling thread.  Used by hybrid SDKs (React Native, Flutter, .NET, Unity)
 * to prevent duplicate crash reports when the host runtime is about to raise a
 * signal (e.g. SIGABRT) that has already been captured as a managed exception.
 *
 * NOTE: upstream KSCrash does not expose a per-thread signal-ignore API.
 * This function is currently a no-op.  A future change can wire it through
 * once KSCrash gains the corresponding facility.
 *
 * @param signum The signal number to ignore on the next delivery (e.g. SIGABRT).
 */
void sentrycrash_ignore_next_signal(int signum);

#ifdef __cplusplus
}
#endif

#endif // SentryKSCrashIgnoreNextSignal_h
