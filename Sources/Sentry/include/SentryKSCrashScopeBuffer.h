#ifndef SentryKSCrashScopeBuffer_h
#define SentryKSCrashScopeBuffer_h

#ifdef __cplusplus
extern "C" {
#endif

/// Stores a pre-serialized JSON string for the sentry_sdk_scope report field.
/// Thread-safe. NOT async-signal-safe — call only from normal app threads.
void sentryKSCrash_setScopeJSON(const char *json);

/// Returns the stored JSON. Async-safe (pointer read only, no allocation).
/// Called from the crash-time isWritingReportCallback.
const char *sentryKSCrash_getScopeJSON(void);

#ifdef __cplusplus
}
#endif

#endif /* SentryKSCrashScopeBuffer_h */
