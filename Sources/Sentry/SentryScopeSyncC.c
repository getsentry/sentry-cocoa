#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define NUMBER_OF_FIELDS 3
static const char *g_userJSON;
static const char *g_distJSON;
static const char *g_contextJSON;
static const char *g_environmentJSON;

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

void
sentryscopesync_getJSON(char **json, size_t *jsonSize)
{

    size_t resultSize = sentrysocpesync_getSize(g_userJSON) + sentrysocpesync_getSize(g_distJSON)
        + sentrysocpesync_getSize(g_contextJSON) + sentrysocpesync_getSize(g_environmentJSON)
        + NUMBER_OF_FIELDS;
    char *result = malloc(resultSize);

    sentrysocpesync_add(result, g_userJSON);
    sentrysocpesync_add(result, g_distJSON);
    sentrysocpesync_add(result, g_contextJSON);
    sentrysocpesync_add(result, g_environmentJSON);

    result[strlen(result) - 1] = '\0';

    *json = result;
    *jsonSize = resultSize;
}

void
sentryscopesync_set(const char *const newJSON, const char **field)
{
    if (field != NULL) {
        free((void *)*field);
    }
    if (newJSON == NULL) {
        *field = NULL;
    } else {
        *field = strdup(newJSON);
    }
}

void
sentryscopesync_setUserJSON(const char *const userJSON)
{
    sentryscopesync_set(userJSON, &g_userJSON);
}

void
sentryscopesync_setDist(const char *const distJSON)
{
    sentryscopesync_set(distJSON, &g_distJSON);
}

void
sentryscopesync_setContext(const char *const contextJSON)
{
    sentryscopesync_set(contextJSON, &g_contextJSON);
}

void
sentryscopesync_setEnvironment(const char *const environmentJSON)
{
    sentryscopesync_set(environmentJSON, &g_environmentJSON);
}

void
sentryscopesync_clear(void)
{
    sentryscopesync_setUserJSON(NULL);
    sentryscopesync_setDist(NULL);
    sentryscopesync_setContext(NULL);
    sentryscopesync_setEnvironment(NULL);
}
