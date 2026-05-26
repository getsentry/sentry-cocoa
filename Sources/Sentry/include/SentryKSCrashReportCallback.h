#ifndef SentryKSCrashReportCallback_h
#define SentryKSCrashReportCallback_h

#ifdef __OBJC__
@import KSCrashRecording;
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Finishes and saves the active transaction so it can be attached to the crash event.
/// Implemented in Swift (SentryCrashIntegration.swift) with @_cdecl.
void sentry_finishAndSaveTransaction(void);

/// isWritingReportCallback for KSCrashConfiguration.
/// Reads pre-stored scope JSON (written from Swift before crash) and
/// injects it as "sentry_sdk_scope" inside the crash report's "user" object.
/// Async-safe: only reads a pointer and calls writer function pointers.
/// Signature matches KSCrashIsWritingReportCallback typedef.
void sentry_kscrash_isWritingReportCallback(
    const KSCrash_ExceptionHandlingPlan *plan, const KSCrashReportWriter *writer);

/// willWriteReportCallback for KSCrashConfiguration.
/// Finishes and persists the active transaction so it can be attached to the
/// crash event on next launch. Called before the crash report is written.
/// Signature matches KSCrashWillWriteReportCallback typedef.
void sentry_kscrash_willWriteReportCallback(
    KSCrash_ExceptionHandlingPlan *plan, const struct KSCrash_MonitorContext *context);

#ifdef __cplusplus
}
#endif

#endif /* SentryKSCrashReportCallback_h */
