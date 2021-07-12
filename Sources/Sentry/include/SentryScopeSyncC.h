#ifndef SentryScopeSyncC_h
#define SentryScopeSyncC_h

/**
 * Stitches together all passed in scope JSON fields and returns it as a full JSON.
 */
void sentryscopesync_getJSON(char **json);

void sentryscopesync_setUser(const char *const json);

void sentryscopesync_setDist(const char *const json);

void sentryscopesync_setContext(const char *const json);

void sentryscopesync_setEnvironment(const char *const json);

void sentryscopesync_setTags(const char *const json);

void sentryscopesync_setExtras(const char *const json);

void sentryscopesync_setFingerprint(const char *const json);

void sentryscopesync_setLevel(const char *const json);

/**
 * Needs to be called before adding or clearing breadcrumbs to initialize the storage of the
 * breadcrumbs. Calling this method clears all breadcrumbs.
 */
void sentryscopesync_configureBreadcrumbs(long maxBreadcrumbs);

void sentryscopesync_addBreadcrumb(const char *const json);

void sentryscopesync_clearBreadcrumbs(void);

void sentryscopesync_clear(void);

#endif /* SentryScopeSyncC_h */
