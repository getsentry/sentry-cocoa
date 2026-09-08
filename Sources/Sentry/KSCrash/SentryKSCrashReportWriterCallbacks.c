#if SDK_V10

#    include "SentryKSCrashReportWriterCallbacks.h"
#    include "SentryScopeSyncC.h"
#    include <stddef.h>

static void
writeScopeBreadcrumbs(const KSCrashReportWriter *const writer, SentryCrashScope *scope)
{
    if (scope->breadcrumbs == NULL || scope->maxCrumbs < 1) {
        return;
    }

    int areThereBreadcrumbs = 0;
    for (long i = 0; i < scope->maxCrumbs; i++) {
        if (scope->breadcrumbs[i]) {
            areThereBreadcrumbs = 1;
            break;
        }
    }

    if (areThereBreadcrumbs) {
        writer->beginArray(writer, "breadcrumbs");

        for (long i = 0; i < scope->maxCrumbs; i++) {
            // Ring buffer: currentCrumb is the next write slot, so it is also the oldest entry.
            long index = (scope->currentCrumb + i) % scope->maxCrumbs;
            char *breadcrumb = scope->breadcrumbs[index];
            if (breadcrumb) {
                writer->addJSONElement(writer, "crumb", breadcrumb, false);
            }
        }

        writer->endContainer(writer);
    }
}

static void
writeScope(const KSCrashReportWriter *const writer)
{
    SentryCrashScope *scope = sentrycrash_scopesync_getScope();
    if (scope == NULL) {
        return;
    }

    // KSCrash invokes this callback inside the already-open "user" object.
    // Nest sentry_sdk_scope there so the converter can lift it the same way
    // V9 reads a top-level sentry_sdk_scope sibling.
    writer->beginObject(writer, "sentry_sdk_scope");

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

    writeScopeBreadcrumbs(writer, scope);

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

#    if SENTRY_DISABLE_SENTRYCRASH_V10
    // KSCRASH_TODO(GH-8273, GH-8532): Capture crash-time screenshots into the report
    // attachment directory. Acceptance: SCV10-008 and SCV10-010 in
    // SENTRYCRASH_V10_MIGRATION_LEDGER.md.
    // KSCRASH_TODO(GH-8273, GH-8532): Capture crash-time view hierarchy into the report
    // attachment directory. Acceptance: SCV10-009 and SCV10-010 in
    // SENTRYCRASH_V10_MIGRATION_LEDGER.md.
    // KSCRASH_TODO(GH-8801): Write the session-replay recovery checkpoint after the report
    // is on disk. Acceptance: SCV10-039 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
    // KSCRASH_TODO(GH-8735): Persist the active transaction bound to the scope. Acceptance:
    // SCV10-027 in SENTRYCRASH_V10_MIGRATION_LEDGER.md.
#    endif
}

#endif // SDK_V10
