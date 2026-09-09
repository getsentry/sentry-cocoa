#if SDK_V10

#    include "SentryKSCrashReportWriterCallbacks.h"
#    include "KSFileUtils.h"
#    include "SentryAsyncSafeLog.h"
#    include "SentryScopeSyncC.h"
#    include <dirent.h>
#    include <errno.h>
#    include <fcntl.h>
#    include <inttypes.h>
#    include <limits.h>
#    include <stdatomic.h>
#    include <stdbool.h>
#    include <stdio.h>
#    include <string.h>
#    include <sys/stat.h>
#    include <unistd.h>

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

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Capturing crash attachments for reportID %" PRId64, reportID);
    sentrykscrash_attachments_capture(reportID);

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

static atomic_bool g_attachmentsEnabled = false;
static SentryKSCrashAttachmentsScreenshotWriter g_screenshotWriter;
static KSCrashReportSidecarPathProviderFunc g_getSidecarPath;

static const unsigned char kMarkerHeader[] = { 0xDE, 0xAD, 0xBE, 0xEF, 1 };

void
sentrykscrash_attachments_setEnabled(bool enabled)
{
    atomic_store_explicit(&g_attachmentsEnabled, enabled, memory_order_release);
}

void
sentrykscrash_attachments_setScreenshotWriter(SentryKSCrashAttachmentsScreenshotWriter writer)
{
    g_screenshotWriter = writer;
}

void
sentrykscrash_attachments_setSidecarPathProvider(KSCrashReportSidecarPathProviderFunc provider)
{
    g_getSidecarPath = provider;
}

static bool
isHexChar(char c)
{
    return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F');
}

/** In-place mkdir -p. KSCrash's ksfu_makePath uses strdup, so it is not crash-safe. */
static bool
makePath(char *path)
{
    for (char *p = path + 1; *p != '\0'; p++) {
        if (*p != '/') {
            continue;
        }
        *p = '\0';
        if (mkdir(path, 0755) != 0 && errno != EEXIST) {
            *p = '/';
            return false;
        }
        *p = '/';
    }
    if (mkdir(path, 0755) != 0 && errno != EEXIST) {
        return false;
    }
    return true;
}

/** Null-terminate at the last `/` and return the last path component. */
static const char *
truncateLastPathEntry(char *path)
{
    const char *entry = ksfu_lastPathEntry(path);
    if (entry == path) {
        return NULL;
    }
    ((char *)(entry - 1))[0] = '\0';
    return entry;
}

/** `.../Sidecars/SentryAttachments/<16-hex>.ksscr` → `.../SentryAttachments/<16-hex>/` */
static bool
payloadDirectoryFromSidecar(const char *sidecarPath, char *out, size_t outSize)
{
    char buf[PATH_MAX];
    if (strlcpy(buf, sidecarPath, sizeof(buf)) >= sizeof(buf)) {
        return false;
    }

    const char *fileName = truncateLastPathEntry(buf);
    if (fileName == NULL) {
        return false;
    }
    if (strlen(fileName) != 22 || strcmp(fileName + 16, ".ksscr") != 0) {
        return false;
    }
    char reportIDHex[17];
    memcpy(reportIDHex, fileName, 16);
    reportIDHex[16] = '\0';
    for (int i = 0; i < 16; i++) {
        if (!isHexChar(reportIDHex[i])) {
            return false;
        }
    }

    const char *monitorName = truncateLastPathEntry(buf);
    if (monitorName == NULL || strcmp(monitorName, "SentryAttachments") != 0) {
        return false;
    }

    const char *sidecarsName = truncateLastPathEntry(buf);
    if (sidecarsName == NULL || strcmp(sidecarsName, "Sidecars") != 0) {
        return false;
    }

    // not async-signal safe but accepted
    int written = snprintf(out, outSize, "%s/SentryAttachments/%s", buf, reportIDHex);
    return written > 0 && (size_t)written < outSize;
}

static bool
directoryHasFiles(const char *path)
{
    DIR *dir = opendir(path); // not async-signal safe but accepted
    if (dir == NULL) {
        return false;
    }
    bool found = false;
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) { // not async-signal safe but accepted
        if (entry->d_name[0] == '.') {
            continue;
        }
        found = true;
        break;
    }
    closedir(dir); // not async-signal safe but accepted
    return found;
}

static bool
writeMarker(const char *sidecarPath)
{
    int fd = open(sidecarPath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Failed to open attachments marker %s: %s", sidecarPath, SENTRY_STRERROR_R(errno));
        return false;
    }
    bool ok = ksfu_writeBytesToFD(fd, (const char *)kMarkerHeader, (int)sizeof(kMarkerHeader));
    if (ok && fsync(fd) != 0) {
        ok = false;
    }
    close(fd);
    return ok;
}

void
sentrykscrash_attachments_capture(int64_t reportID)
{
    if (!atomic_load_explicit(&g_attachmentsEnabled, memory_order_acquire)) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Not capturing attachments for reportID %" PRId64 ": monitor is not enabled", reportID);
        return;
    }
    if (reportID <= 0) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG(
            "Not capturing attachments: invalid reportID %" PRId64, reportID);
        return;
    }
    if (g_screenshotWriter == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Not capturing attachments for reportID %" PRId64
                                    ": screenshot writer is not set",
            reportID);
        return;
    }
    if (g_getSidecarPath == NULL) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Not capturing attachments for reportID %" PRId64
                                    ": sidecar path provider is missing",
            reportID);
        return;
    }

    char sidecarPath[PATH_MAX];
    if (!g_getSidecarPath(
            sentrykscrash_attachmentsMonitorID, reportID, sidecarPath, sizeof(sidecarPath))) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Not capturing attachments for reportID %" PRId64
                                    ": sidecar path is unavailable",
            reportID);
        return;
    }

    char payloadDirectory[PATH_MAX];
    if (!payloadDirectoryFromSidecar(sidecarPath, payloadDirectory, sizeof(payloadDirectory))) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Not capturing attachments for reportID %" PRId64
                                    ": payload directory could not be derived from %s",
            reportID, sidecarPath);
        return;
    }

    if (!makePath(payloadDirectory)) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("Failed to create payload directory %s: %s", payloadDirectory,
            SENTRY_STRERROR_R(errno));
        return;
    }

    SENTRY_ASYNC_SAFE_LOG_DEBUG("Calling screenshot writer for %s", payloadDirectory);
    // not async-signal safe but accepted
    g_screenshotWriter(payloadDirectory);
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Screenshot writer returned for %s", payloadDirectory);

    if (!directoryHasFiles(payloadDirectory)) {
        SENTRY_ASYNC_SAFE_LOG_DEBUG("No attachment files written for reportID %" PRId64
                                    ", removing payload directory %s",
            reportID, payloadDirectory);
        rmdir(payloadDirectory);
        return;
    }

    if (!writeMarker(sidecarPath)) {
        return;
    }
    SENTRY_ASYNC_SAFE_LOG_DEBUG("Wrote attachments marker for reportID %" PRId64, reportID);
}

void
sentrykscrash_attachments_handleDidWriteReport(void *context, int64_t reportID)
{
    (void)context;
    sentrykscrash_attachments_capture(reportID);
}

void
sentrykscrash_attachments_log(const char *message)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("%s", message != NULL ? message : "(null)");
}

void
sentrykscrash_attachments_log_i(const char *message, int value)
{
    SENTRY_ASYNC_SAFE_LOG_DEBUG("%s: %d", message != NULL ? message : "", value);
}

#endif // SDK_V10
