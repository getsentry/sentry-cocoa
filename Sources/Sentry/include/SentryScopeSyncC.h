#ifndef SentryScopeSyncC_h
#define SentryScopeSyncC_h

typedef struct {
    char *userJSON;
    char *distJSON;
    char *contextJSON;
    char *environmentJSON;
    char *tagsJSON;
    char *extrasJSON;
    char *fingerprintJSON;
    char *levelJSON;
    char **breadcrumbs; // dynamic array of char arrays
    long maxCrumbs;
    long currentCrumb;
} SentryCrashScope;

SentryCrashScope *sentryscopesync_getScope(void);

/**
 * Needs to be called before adding or clearing breadcrumbs to initialize the storage of the
 * breadcrumbs. Calling this method clears all breadcrumbs.
 */
void sentryscopesync_configureBreadcrumbs(long maxBreadcrumbs);

void sentryscopesync_setUser(const char *const json);

void sentryscopesync_setDist(const char *const json);

void sentryscopesync_setContext(const char *const json);

void sentryscopesync_setEnvironment(const char *const json);

void sentryscopesync_setTags(const char *const json);

void sentryscopesync_setExtras(const char *const json);

void sentryscopesync_setFingerprint(const char *const json);

void sentryscopesync_setLevel(const char *const json);

void sentryscopesync_addBreadcrumb(const char *const json);

void sentryscopesync_clearBreadcrumbs(void);

void sentryscopesync_clear(void);

/**
 * Only needed for testing. Clears the scope, but also sets everything to NULL.
 */
void sentryscopesync_reset(void);

#endif /* SentryScopeSyncC_h */
