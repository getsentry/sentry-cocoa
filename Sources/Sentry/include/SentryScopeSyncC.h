#include <stdlib.h>

#ifndef SentryScopeSyncC_h
#    define SentryScopeSyncC_h

void sentryscopesync_getJSON(char **json);

void sentryscopesync_clear(void);

void sentryscopesync_setUserJSON(const char *const json);

void sentryscopesync_setDist(const char *const json);

void sentryscopesync_setContext(const char *const json);

void sentryscopesync_setEnvironment(const char *const json);

void sentryscopesync_setTags(const char *const json);

void sentryscopesync_setExtras(const char *const json);

void sentryscopesync_setFingerprint(const char *const json);

void sentryscopesync_setLevel(const char *const json);

#endif /* SentryScopeSyncC_h */
