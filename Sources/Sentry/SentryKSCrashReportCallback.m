#import "SentryKSCrashReportCallback.h"
#import "SentryKSCrashScopeBuffer.h"

void
sentry_kscrash_isWritingReportCallback(
    const KSCrash_ExceptionHandlingPlan *plan, const KSCrashReportWriter *writer)
{
    if (plan->crashedDuringExceptionHandling) {
        return;
    }
    const char *json = sentryKSCrash_getScopeJSON();
    if (json != NULL) {
        writer->addJSONElement(writer, "sentry_sdk_scope", json, false);
    }
}

void
sentry_kscrash_willWriteReportCallback(
    KSCrash_ExceptionHandlingPlan *plan, const struct KSCrash_MonitorContext *context)
{
    if (plan->crashedDuringExceptionHandling || plan->requiresAsyncSafety) {
        return;
    }
    sentry_finishAndSaveTransaction();
}
