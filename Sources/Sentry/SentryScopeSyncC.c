#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 9
#define MAX_BREADCRUMBS 100
static const char *g_userJSON;
static const char *g_distJSON;
static const char *g_contextJSON;
static const char *g_environmentJSON;
static const char *g_tagsJSON;
static const char *g_extrasJSON;
static const char *g_fingerprintJSON;
static const char *g_levelJSON;
static const char *g_breadcrumbs[MAX_BREADCRUMBS];
static int currentCrumb = 0;
static size_t rawBreadcrumbSize = 100 + MAX_BREADCRUMBS + 1;

void
sentrysocpesync_add(char *destination, const char *source)
{
    if (source != NULL) {
        strcat(destination, source);
        strcat(destination, ",");
    }
}

size_t
sentrysocpesync_getSize(const char *str)
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
    size_t size = rawBreadcrumbSize;
    for (int i = 0; i < MAX_BREADCRUMBS; i++) {
        size += sentrysocpesync_getSize(g_breadcrumbs[i]);
    }
    return size;
}

void
sentrysocpesync_addBreadcrumbs(char *destination)
{
    size_t size = sentrysocpesync_getBreadcrumbSize();
    char *crumbs = malloc(size);

    // No crumbs nothing to add
    if (size == rawBreadcrumbSize) {
        return;
    }

    strcat(crumbs, "\"breadcrumbs\":[");
    for (int i = 0; i < MAX_BREADCRUMBS; i++) {
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
    size_t resultSize = sentrysocpesync_getSize(g_userJSON) + sentrysocpesync_getSize(g_distJSON)
        + sentrysocpesync_getSize(g_contextJSON) + sentrysocpesync_getSize(g_environmentJSON)
        + sentrysocpesync_getSize(g_tagsJSON) + sentrysocpesync_getSize(g_extrasJSON)
        + sentrysocpesync_getSize(g_fingerprintJSON) + sentrysocpesync_getSize(g_levelJSON)
        + sentrysocpesync_getBreadcrumbSize() + NUMBER_OF_FIELDS + brackets + nullByte;

    char *result = calloc(1, resultSize);

    if (resultSize == NUMBER_OF_FIELDS + brackets + nullByte + rawBreadcrumbSize) {
        // All fields are empty
        strcat(result, "{}");
    } else {
        strcat(result, "{");
        sentrysocpesync_add(result, g_userJSON);
        sentrysocpesync_add(result, g_distJSON);
        sentrysocpesync_add(result, g_contextJSON);
        sentrysocpesync_add(result, g_environmentJSON);
        sentrysocpesync_add(result, g_tagsJSON);
        sentrysocpesync_add(result, g_extrasJSON);
        sentrysocpesync_add(result, g_fingerprintJSON);
        sentrysocpesync_add(result, g_levelJSON);
        sentrysocpesync_addBreadcrumbs(result);

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
sentryscopesync_setUserJSON(const char *const json)
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
    currentCrumb = (currentCrumb + 1) % MAX_BREADCRUMBS;
}

void
sentryscopesync_clearBreadcrumbs(void)
{
    for (int i = 0; i < MAX_BREADCRUMBS; i++) {
        sentryscopesync_set(NULL, &g_breadcrumbs[i]);
    }
}

void
sentryscopesync_clear(void)
{
    sentryscopesync_setUserJSON(NULL);
    sentryscopesync_setDist(NULL);
    sentryscopesync_setContext(NULL);
    sentryscopesync_setEnvironment(NULL);
    sentryscopesync_setTags(NULL);
    sentryscopesync_setExtras(NULL);
    sentryscopesync_setFingerprint(NULL);
    sentryscopesync_setLevel(NULL);
    sentryscopesync_clearBreadcrumbs();
}
