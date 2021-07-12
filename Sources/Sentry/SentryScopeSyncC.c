#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 9
static const char *g_userJSON;
static const char *g_distJSON;
static const char *g_contextJSON;
static const char *g_environmentJSON;
static const char *g_tagsJSON;
static const char *g_extrasJSON;
static const char *g_fingerprintJSON;
static const char *g_levelJSON;

static long g_maxBreadcrumbs = 0;
static const char **g_breadcrumbs;
static int currentCrumb = 0;
static const char *g_breadcrumbs_start = "\"breadcrumbs\":[";

size_t
getRawBreadcrumbSize(void)
{
    size_t addionitalChars = 3;
    return sizeof(g_breadcrumbs_start) + g_maxBreadcrumbs + addionitalChars + 1;
}

void
sentryscopesync_add(char *destination, const char *source)
{
    if (source != NULL) {
        strcat(destination, source);
        strcat(destination, ",");
    }
}

size_t
sentryscopesync_getSize(const char *str)
{
    size_t size = 0;
    if (str != NULL) {
        size = strlen(str);
    }
    return size;
}

size_t
sentrysocpesync_getBreadcrumbSize(void)
{
    size_t size = getRawBreadcrumbSize();
    for (int i = 0; i < g_maxBreadcrumbs; i++) {
        size += sentryscopesync_getSize(g_breadcrumbs[i]);
    }
    return size;
}

void
sentryscopesync_addBreadcrumbs(char *destination)
{
    size_t size = sentrysocpesync_getBreadcrumbSize();
    char *crumbs = malloc(size);

    // No crumbs nothing to add
    if (size == getRawBreadcrumbSize()) {
        return;
    }

    strcat(crumbs, g_breadcrumbs_start);
    for (int i = 0; i < g_maxBreadcrumbs; i++) {
        if (g_breadcrumbs[i] != NULL) {
            strcat(crumbs, "{");
            strcat(crumbs, g_breadcrumbs[i]);
            strcat(crumbs, "},");
        }
    }

    size_t length = strlen(crumbs);
    crumbs[length - 1] = ']';
    crumbs[length] = '\0';
    strcat(crumbs, ",");

    strcat(destination, crumbs);

    free(crumbs);
}

void
sentryscopesync_getJSON(char **json)
{
    size_t brackets = 2;
    size_t nullByte = 1;
    size_t resultSize = sentryscopesync_getSize(g_userJSON) + sentryscopesync_getSize(g_distJSON)
        + sentryscopesync_getSize(g_contextJSON) + sentryscopesync_getSize(g_environmentJSON)
        + sentryscopesync_getSize(g_tagsJSON) + sentryscopesync_getSize(g_extrasJSON)
        + sentryscopesync_getSize(g_fingerprintJSON) + sentryscopesync_getSize(g_levelJSON)
        + sentrysocpesync_getBreadcrumbSize() + NUMBER_OF_FIELDS + brackets + nullByte;

    char *result = calloc(1, resultSize);

    if (resultSize == NUMBER_OF_FIELDS + brackets + nullByte + getRawBreadcrumbSize()) {
        // All fields are empty
        strcat(result, "{}");
    } else {
        strcat(result, "{");
        sentryscopesync_add(result, g_userJSON);
        sentryscopesync_add(result, g_distJSON);
        sentryscopesync_add(result, g_contextJSON);
        sentryscopesync_add(result, g_environmentJSON);
        sentryscopesync_add(result, g_tagsJSON);
        sentryscopesync_add(result, g_extrasJSON);
        sentryscopesync_add(result, g_fingerprintJSON);
        sentryscopesync_add(result, g_levelJSON);
        sentryscopesync_addBreadcrumbs(result);

        size_t length = strlen(result);
        result[length - 1] = '}';
        result[length] = '\0';
    }

    *json = result;
}

void
sentryscopesync_set(const char *const newJSON, const char **field)
{
    free((void *)*field);
    if (newJSON == NULL) {
        *field = NULL;
    } else {
        *field = strdup(newJSON);
    }
}

void
sentryscopesync_setUser(const char *const json)
{
    sentryscopesync_set(json, &g_userJSON);
}

void
sentryscopesync_setDist(const char *const json)
{
    sentryscopesync_set(json, &g_distJSON);
}

void
sentryscopesync_setContext(const char *const json)
{
    sentryscopesync_set(json, &g_contextJSON);
}

void
sentryscopesync_setEnvironment(const char *const json)
{
    sentryscopesync_set(json, &g_environmentJSON);
}

void
sentryscopesync_setTags(const char *const json)
{
    sentryscopesync_set(json, &g_tagsJSON);
}

void
sentryscopesync_setExtras(const char *const json)
{
    sentryscopesync_set(json, &g_extrasJSON);
}

void
sentryscopesync_setFingerprint(const char *const json)
{
    sentryscopesync_set(json, &g_fingerprintJSON);
}

void
sentryscopesync_setLevel(const char *const json)
{
    sentryscopesync_set(json, &g_levelJSON);
}

void
sentryscopesync_addBreadcrumb(const char *const json)
{
    sentryscopesync_set(json, &g_breadcrumbs[currentCrumb]);
    // Ring buffer
    currentCrumb = (currentCrumb + 1) % g_maxBreadcrumbs;
}

void
sentryscopesync_clearBreadcrumbs(void)
{
    for (int i = 0; i < g_maxBreadcrumbs; i++) {
        sentryscopesync_set(NULL, &g_breadcrumbs[i]);
    }
}

void
sentryscopesync_configureBreadcrumbs(long maxBreadcrumbs)
{
    g_maxBreadcrumbs = maxBreadcrumbs;
    size_t size = sizeof(char *) * g_maxBreadcrumbs;
    g_breadcrumbs = malloc(size);
    for (int i = 0; i < g_maxBreadcrumbs; i++) {
        g_breadcrumbs[i] = NULL;
    }
    sentryscopesync_clearBreadcrumbs();
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
