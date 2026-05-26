#ifndef SentryKSCrashReportCallback_h
#define SentryKSCrashReportCallback_h

#ifdef __OBJC__
@import KSCrashRecording;
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// isWritingReportCallback for KSCrashConfiguration.
/// Reads pre-stored scope JSON (written from Swift before crash) and
/// injects it as "sentry_sdk_scope" inside the crash report's "user" object.
/// Async-safe: only reads a pointer and calls writer function pointers.
/// Signature matches KSCrashIsWritingReportCallback typedef.
void sentry_kscrash_isWritingReportCallback(
    const KSCrash_ExceptionHandlingPlan *plan, const KSCrashReportWriter *writer);

#ifdef __cplusplus
}
#endif

#endif /* SentryKSCrashReportCallback_h */
