#ifndef SentryKSCrashReportWriterCallbacks_h
#define SentryKSCrashReportWriterCallbacks_h

#if SDK_V10

#    include "KSCrashMonitorContext.h"
#    include "KSCrashReportWriter.h"
#    include "KSCrashReportWriterCallbacks.h"
#    include <stdbool.h>
#    include <stdint.h>

#    ifdef __cplusplus
extern "C" {
#    endif

void sentrykscrash_willWriteReport(KSCrash_ExceptionHandlingPlan *_Nonnull const plan,
    const struct KSCrash_MonitorContext *_Nonnull context);

void sentrykscrash_isWritingReport(const KSCrash_ExceptionHandlingPlan *_Nonnull const plan,
    const KSCrashReportWriter *_Nonnull writer);

void sentrykscrash_didWriteReport(
    const KSCrash_ExceptionHandlingPlan *_Nonnull const plan, int64_t reportID);

/** KSCrash plugin ID for crash-time attachments. Must match the Swift monitor ID. */
extern const char *const _Nonnull sentrykscrash_attachmentsMonitorID;

typedef void (*SentryKSCrashAttachmentsScreenshotWriter)(const char *_Nonnull payloadDirectory);
typedef void (*SentryKSCrashAttachmentsViewHierarchyWriter)(const char *_Nonnull payloadDirectory);

const char *_Nullable sentrykscrash_attachments_monitorId(void *_Nullable context);
bool sentrykscrash_attachments_isEnabled(void *_Nullable context);
void sentrykscrash_attachments_setEnabled(bool enabled, void *_Nullable context);
void sentrykscrash_attachments_setScreenshotWriter(
    SentryKSCrashAttachmentsScreenshotWriter _Nullable writer);
void sentrykscrash_attachments_setViewHierarchyWriter(
    SentryKSCrashAttachmentsViewHierarchyWriter _Nullable writer);
void sentrykscrash_attachments_setSidecarPathProvider(
    KSCrashReportSidecarPathProviderFunc _Nullable provider);

/**
 * This is accepted as not being a async-signal-safe operation.
 * It represents a best-effort attempt at grabbing useful information before the application is
 * terminated.
 */
void sentrykscrash_attachments_capture(int64_t reportID);

/** Async-signal-safe log into `Caches/io.sentry/async.log`. */
void sentrykscrash_attachments_log(const char *_Nonnull message);
void sentrykscrash_attachments_log_i(const char *_Nonnull message, int value);

void sentrykscrash_attachments_handleDidWriteReport(void *_Nullable context, int64_t reportID);

#    ifdef __cplusplus
}
#    endif

#endif // SDK_V10

#endif /* SentryKSCrashReportWriterCallbacks_h */
