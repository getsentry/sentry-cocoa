#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 9

static const char *userJSON;
static pthread_mutex_t userMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *distJSON;
static pthread_mutex_t distMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *contextJSON;
static pthread_mutex_t contextMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *environmentJSON;
static pthread_mutex_t environmentMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *tagsJSON;
static pthread_mutex_t tagsMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *extrasJSON;
static pthread_mutex_t extrasMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *fingerprintJSON;
static pthread_mutex_t fingerprintMutex = PTHREAD_MUTEX_INITIALIZER;

static const char *levelJSON;
static pthread_mutex_t levelMutex = PTHREAD_MUTEX_INITIALIZER;

static long maxCrumbs = 0;
static int currentCrumb = 0;
static const char **breadcrumbs; // dynamic array of char arrays
static const char *breadcrumbsStart = "\"breadcrumbs\":[";
static pthread_mutex_t breadrumbsMutex = PTHREAD_MUTEX_INITIALIZER;

static void
add(char *destination, const char *source)
{
    if (source != NULL) {
        strcat(destination, source);
        strcat(destination, ",");
    }
}

static size_t
getSize(const char *str)
{
    size_t size = 0;
    if (str != NULL) {
        size = strlen(str);
    }
    return size;
}

static size_t
getRawBreadcrumbSize(void)
{
    size_t addionitalChars = 3;
    return sizeof(breadcrumbsStart) + maxCrumbs + addionitalChars + 1;
}

static size_t
getBreadcrumbSize(void)
{
    size_t size = getRawBreadcrumbSize();
    for (int i = 0; i < maxCrumbs; i++) {
        size += getSize(breadcrumbs[i]);
    }
    return size;
}

static void
addBreadcrumbs(char *destination)
{
    size_t size = getBreadcrumbSize();
    char *crumbs = malloc(size);

    // No crumbs nothing to add
    if (size == getRawBreadcrumbSize()) {
        return;
    }

    strcat(crumbs, breadcrumbsStart);
    for (int i = 0; i < maxCrumbs; i++) {
        if (breadcrumbs[i] != NULL) {
            strcat(crumbs, "{");
            strcat(crumbs, breadcrumbs[i]);
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

/**
 * We don't lock access to the properties in this method as this is called when a crash occurs.
 */
void
sentryscopesync_getJSON(char **json)
{
    size_t brackets = 2;
    size_t nullByte = 1;
    size_t resultSize = getSize(userJSON) + getSize(distJSON) + getSize(contextJSON)
        + getSize(environmentJSON) + getSize(tagsJSON) + getSize(extrasJSON)
        + getSize(fingerprintJSON) + getSize(levelJSON) + getBreadcrumbSize() + NUMBER_OF_FIELDS
        + brackets + nullByte;

    char *result = calloc(1, resultSize);

    if (resultSize == NUMBER_OF_FIELDS + brackets + nullByte + getRawBreadcrumbSize()) {
        // All fields are empty
        strcat(result, "{}");
    } else {
        strcat(result, "{");
        add(result, userJSON);
        add(result, distJSON);
        add(result, contextJSON);
        add(result, environmentJSON);
        add(result, tagsJSON);
        add(result, extrasJSON);
        add(result, fingerprintJSON);
        add(result, levelJSON);
        addBreadcrumbs(result);

        size_t length = strlen(result);
        result[length - 1] = '}';
        result[length] = '\0';
    }

    *json = result;
}

static void
setUnlocked(const char *const newJSON, const char **field)
{
    free((void *)*field);
    if (newJSON == NULL) {
        *field = NULL;
    } else {
        *field = strdup(newJSON);
    }
}

static void
set(const char *const newJSON, const char **field, pthread_mutex_t * mutex)
{
    pthread_mutex_lock(mutex);
    setUnlocked(newJSON, field);
    pthread_mutex_unlock(mutex);
}

void
sentryscopesync_setUser(const char *const json)
{
    set(json, &userJSON, &userMutex);
}

void
sentryscopesync_setDist(const char *const json)
{
    set(json, &distJSON, &distMutex);
}

void
sentryscopesync_setContext(const char *const json)
{
    set(json, &contextJSON, &contextMutex);
}

void
sentryscopesync_setEnvironment(const char *const json)
{
    set(json, &environmentJSON, &environmentMutex);
}

void
sentryscopesync_setTags(const char *const json)
{
    set(json, &tagsJSON, &tagsMutex);
}

void
sentryscopesync_setExtras(const char *const json)
{
    set(json, &extrasJSON, &extrasMutex);
}

void
sentryscopesync_setFingerprint(const char *const json)
{
    set(json, &fingerprintJSON, &fingerprintMutex);
}

void
sentryscopesync_setLevel(const char *const json)
{
    set(json, &levelJSON, &levelMutex);
}

void
sentryscopesync_addBreadcrumb(const char *const json)
{
    pthread_mutex_lock(&breadrumbsMutex);
    setUnlocked(json, &breadcrumbs[currentCrumb]);
    // Ring buffer
    currentCrumb = (currentCrumb + 1) % maxCrumbs;
    pthread_mutex_unlock(&breadrumbsMutex);
}


static void clearBreadcrumbsUnlocked(void)
{
    for (int i = 0; i < maxCrumbs; i++) {
        setUnlocked(NULL, &breadcrumbs[i]);
    }
}

void
sentryscopesync_clearBreadcrumbs(void)
{
    pthread_mutex_lock(&breadrumbsMutex);
    clearBreadcrumbsUnlocked();
    pthread_mutex_unlock(&breadrumbsMutex);
}

void
sentryscopesync_configureBreadcrumbs(long maxBreadcrumbs)
{
    
    pthread_mutex_lock(&breadrumbsMutex);
    maxCrumbs = maxBreadcrumbs;
    size_t size = sizeof(char *) * maxCrumbs;
    breadcrumbs = malloc(size);
    for (int i = 0; i < maxCrumbs; i++) {
        breadcrumbs[i] = NULL;
    }
    clearBreadcrumbsUnlocked();
    pthread_mutex_unlock(&breadrumbsMutex);
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
