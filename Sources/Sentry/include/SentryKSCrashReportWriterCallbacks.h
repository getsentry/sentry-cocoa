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

void sentrykscrash_attachments_setEnabled(bool enabled);
void sentrykscrash_attachments_setScreenshotWriter(
    SentryKSCrashAttachmentsScreenshotWriter _Nullable writer);
void sentrykscrash_attachments_setSidecarPathProvider(
    KSCrashReportSidecarPathProviderFunc _Nullable provider);

/** Crash-time capture. No Swift, no locks, no heap. */
void sentrykscrash_attachments_capture(int64_t reportID);

void sentrykscrash_attachments_handleDidWriteReport(void *_Nullable context, int64_t reportID);

#    ifdef __cplusplus
}
#    endif

#endif // SDK_V10

#endif /* SentryKSCrashReportWriterCallbacks_h */
