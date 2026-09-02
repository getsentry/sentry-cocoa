#ifndef SentryKSCrashReportWriterCallbacks_h
#define SentryKSCrashReportWriterCallbacks_h

#if SDK_V10

#    include "KSCrashMonitorContext.h"
#    include "KSCrashReportWriter.h"
#    include "KSCrashReportWriterCallbacks.h"
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

/** Called after a fatal report has been written. Receives the KSCrash report ID. */
typedef void (*SentryKSCrashAttachmentsDidWriteHandler)(int64_t reportID);

void sentrykscrash_setAttachmentsDidWriteHandler(
    SentryKSCrashAttachmentsDidWriteHandler _Nullable handler);

#    ifdef __cplusplus
}
#    endif

#endif // SDK_V10

#endif /* SentryKSCrashReportWriterCallbacks_h */
