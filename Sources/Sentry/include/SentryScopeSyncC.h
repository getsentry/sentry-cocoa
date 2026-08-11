#ifndef SentryScopeSyncC_h
#define SentryScopeSyncC_h

typedef struct {
    char *_Nullable user;
    char *_Nullable dist;
    char *_Nullable context;
    char *_Nullable traceContext;
    char *_Nullable environment;
    char *_Nullable tags;
    char *_Nullable extras;
    char *_Nullable fingerprint;
    char *_Nullable level;
    char *_Nullable *_Nullable breadcrumbs; // dynamic array of char arrays
    long maxCrumbs;
    long currentCrumb;

} SentryCrashScope;

SentryCrashScope *_Nonnull sentrycrash_scopesync_getScope(void);

/**
 * Needs to be called before adding or clearing breadcrumbs to initialize the storage of the
 * breadcrumbs. Calling this method clears all breadcrumbs.
 */
void sentrycrash_scopesync_configureBreadcrumbs(long maxBreadcrumbs);

void sentrycrash_scopesync_setUser(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setDist(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setContext(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setTraceContext(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setEnvironment(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setTags(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setExtras(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setFingerprint(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_setLevel(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_addBreadcrumb(const char *_Nullable const jsonEncodedCString);

void sentrycrash_scopesync_clearBreadcrumbs(void);

void sentrycrash_scopesync_clear(void);

/**
 * Only needed for testing. Clears the scope, but also sets everything to NULL.
 */
void sentrycrash_scopesync_reset(void);

#endif /* SentryScopeSyncC_h */
