#include "SentryScopeSyncC.h"
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 9

static SentryCrashScope scope = { 0 };

SentryCrashScope *
sentryscopesync_getScope(void)
{
    return &scope;
}

static void
set(const char *const newJSON, char **field)
{
    char *localField = *field;
    *field = NULL;
    if (localField != NULL) {
        free((void *)localField);
    }

    if (newJSON != NULL) {
        *field = strdup(newJSON);
    }
}

void
sentryscopesync_setUser(const char *const json)
{
    set(json, &scope.userJSON);
}

void
sentryscopesync_setDist(const char *const json)
{
    set(json, &scope.distJSON);
}

void
sentryscopesync_setContext(const char *const json)
{
    set(json, &scope.contextJSON);
}

void
sentryscopesync_setEnvironment(const char *const json)
{
    set(json, &scope.environmentJSON);
}

void
sentryscopesync_setTags(const char *const json)
{
    set(json, &scope.tagsJSON);
}

void
sentryscopesync_setExtras(const char *const json)
{
    set(json, &scope.extrasJSON);
}

void
sentryscopesync_setFingerprint(const char *const json)
{
    set(json, &scope.fingerprintJSON);
}

void
sentryscopesync_setLevel(const char *const json)
{
    set(json, &scope.levelJSON);
}

void
sentryscopesync_addBreadcrumb(const char *const json)
{
    if (!scope.breadcrumbs) {
        return;
    }

    set(json, &scope.breadcrumbs[scope.currentCrumb]);
    // Ring buffer
    scope.currentCrumb = (scope.currentCrumb + 1) % scope.maxCrumbs;
}

void
sentryscopesync_clearBreadcrumbs(void)
{
    if (!scope.breadcrumbs) {
        return;
    }

    for (int i = 0; i < scope.maxCrumbs; i++) {
        set(NULL, &scope.breadcrumbs[i]);
    }

    scope.currentCrumb = 0;
}

void
sentryscopesync_configureBreadcrumbs(long maxBreadcrumbs)
{
    scope.maxCrumbs = maxBreadcrumbs;
    size_t size = sizeof(char *) * scope.maxCrumbs;
    scope.currentCrumb = 0;
    if (scope.breadcrumbs) {
        free((void *)scope.breadcrumbs);
    }
    scope.breadcrumbs = malloc(size);
    memset(scope.breadcrumbs, 0, size);
}

void
sentryscopesync_clear(void)
{
    sentryscopesync_setUser(NULL);
    sentryscopesync_setDist(NULL);
    sentryscopesync_setContext(NULL);
    sentryscopesync_setEnvironment(NULL);
    sentryscopesync_setTags(NULL);
    sentryscopesync_setExtras(NULL);
    sentryscopesync_setFingerprint(NULL);
    sentryscopesync_setLevel(NULL);
    sentryscopesync_clearBreadcrumbs();
}

void
sentryscopesync_reset(void)
{
    sentryscopesync_clear();
    scope.breadcrumbs = NULL;
}
