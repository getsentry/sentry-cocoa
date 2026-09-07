#if SDK_V10

#    include "SentryKSCrashReportWriterCallbacks.h"
#    include "KSCrashMonitor.h"
#    include "SentryAsyncSafeLog.h"
#    include "SentryScopeSyncC.h"
#    include <inttypes.h>
#    include <stddef.h>

const char *const sentrykscrash_attachmentsMonitorID = "SentryAttachments";

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
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping scope write: no synced scope");
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
    (void)context;
    if (plan == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("willWriteReport: plan is NULL");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_TRACE(
        "willWriteReport isFatal=%d isCleanExit=%d crashedDuringExceptionHandling=%d",
        plan->isFatal, plan->isCleanExit, plan->crashedDuringExceptionHandling);
}

void
sentrykscrash_isWritingReport(
    const KSCrash_ExceptionHandlingPlan *const plan, const KSCrashReportWriter *const writer)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE("isWritingReport");
    if (writer == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping scope write: writer is NULL");
        return;
    }

    // Recrash: only record enough to diagnose the handler itself.
    if (plan != NULL && plan->crashedDuringExceptionHandling) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping scope write: crashed during exception handling");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Writing SDK scope into crash report");
    writeScope(writer);
}

void
sentrykscrash_didWriteReport(const KSCrash_ExceptionHandlingPlan *const plan, int64_t reportID)
{
    SENTRY_ASYNC_SAFE_LOG_TRACE("didWriteReport reportID=%" PRId64, reportID);
    if (plan == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping crash attachments: plan is NULL");
        return;
    }
    if (!plan->isFatal) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping crash attachments: exception is not fatal");
        return;
    }
    if (plan->isCleanExit) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Skipping crash attachments: clean exit");
        return;
    }
    if (plan->crashedDuringExceptionHandling) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Skipping crash attachments: crashed during exception handling");
        return;
    }
    if (reportID <= 0) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Skipping crash attachments: invalid reportID %" PRId64, reportID);
        return;
    }

    const KSCrashMonitorAPI *api = kscm_getMonitor(sentrykscrash_attachmentsMonitorID);
    if (api == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Skipping crash attachments: SentryAttachments monitor not found");
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Capturing crash attachments for reportID %" PRId64, reportID);
    sentrykscrash_attachments_handleDidWriteReport(api->context, reportID);

#    if SENTRY_DISABLE_SENTRYCRASH_V10
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
