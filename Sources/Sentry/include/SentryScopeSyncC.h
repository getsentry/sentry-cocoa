#include <stdlib.h>

#ifndef SentryScopeSyncC_h
#    define SentryScopeSyncC_h

void sentryscopesync_getJSON(char **json);

void sentryscopesync_clear(void);

void sentryscopesync_setUserJSON(const char *const userJSON);

void sentryscopesync_setDist(const char *const distJSON);

void sentryscopesync_setContext(const char *const contextJSON);

void sentryscopesync_setEnvironment(const char *const environmentJSON);

void sentryscopesync_setTags(const char *const tagsJSON);

void sentryscopesync_setExtras(const char *const extrasJSON);

void sentryscopesync_setFingerprint(const char *const fingerprintJSON);

void sentryscopesync_setLevel(const char *const json);

#endif /* SentryScopeSyncC_h */
