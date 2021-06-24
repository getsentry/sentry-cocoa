#include <stdlib.h>

#ifndef SentryScopeSyncC_h
#    define SentryScopeSyncC_h

void sentryscopesync_getJSON(char **json, size_t *jsonSize);

void sentryscopesync_clear(void);

void sentryscopesync_setUserJSON(const char *const userJSON);

void sentryscopesync_setDist(const char *const distJSON);

void sentryscopesync_setContext(const char *const contextJSON);

void sentryscopesync_setEnvironment(const char *const environmentJSON);

#endif /* SentryScopeSyncC_h */
