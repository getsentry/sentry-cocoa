#if SDK_V10

#    include "SentryKSCrashReportWriterCallbacks.h"
#    include "SentryScopeSyncC.h"
#    include <stddef.h>

static void
writeScope(const KSCrashReportWriter *const writer)
{
    SentryCrashScope *scope = sentrycrash_scopesync_getScope();
    if (scope == NULL) {
        return;
    }

    if (scope->user) {
        writer->addJSONElement(writer, "user", scope->user, false);
    }
    if (scope->dist) {
        writer->addJSONElement(writer, "dist", scope->dist, false);
    }
    if (scope->context) {
        writer->addJSONElement(writer, "context", scope->context, false);
    }
    if (scope->traceContext) {
        writer->addJSONElement(writer, "traceContext", scope->traceContext, false);
    }
    if (scope->environment) {
        writer->addJSONElement(writer, "environment", scope->environment, false);
    }
    if (scope->tags) {
        writer->addJSONElement(writer, "tags", scope->tags, false);
    }
    if (scope->extras) {
        writer->addJSONElement(writer, "extra", scope->extras, false);
    }
    if (scope->fingerprint) {
        writer->addJSONElement(writer, "fingerprint", scope->fingerprint, false);
    }
    if (scope->level) {
        writer->addJSONElement(writer, "level", scope->level, false);
    }

    if (scope->breadcrumbs == NULL || scope->maxCrumbs < 1) {
        return;
    }

    int areThereBreadcrumbs = 0;
    long i;
    for (i = 0; i < scope->maxCrumbs; i++) {
        if (scope->breadcrumbs[i]) {
            areThereBreadcrumbs = 1;
            break;
        }
    }

    if (!areThereBreadcrumbs) {
        return;
    }

    writer->beginArray(writer, "breadcrumbs");
    for (i = 0; i < scope->maxCrumbs; i++) {
        // Ring buffer: currentCrumb is the next write slot, so it is also the oldest entry.
        long index = (scope->currentCrumb + i) % scope->maxCrumbs;
        if (scope->breadcrumbs[index]) {
            writer->addJSONElement(writer, "crumb", scope->breadcrumbs[index], false);
        }
    }
    writer->endContainer(writer);
}

void
sentrykscrash_willWriteReport(
    KSCrash_ExceptionHandlingPlan *const plan, const struct KSCrash_MonitorContext *context)
{
    (void)plan;
    (void)context;
}

void
sentrykscrash_isWritingReport(
    const KSCrash_ExceptionHandlingPlan *const plan, const KSCrashReportWriter *const writer)
{
    if (writer == NULL) {
        return;
    }

    // Recrash: only record enough to diagnose the handler itself.
    if (plan != NULL && plan->crashedDuringExceptionHandling) {
        return;
    }

    writeScope(writer);
}

void
sentrykscrash_didWriteReport(const KSCrash_ExceptionHandlingPlan *const plan, int64_t reportID)
{
    (void)plan;
    (void)reportID;
}

#endif // SDK_V10
