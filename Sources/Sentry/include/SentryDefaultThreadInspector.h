#if SDK_V10
#    include "SentryThreadSnapshot.h"
#else
#    import "SentryCrashStackCursor.h"
#    import "SentryCrashThread.h"
#endif
#import <Foundation/Foundation.h>

@class SentryStacktraceBuilder;

#ifdef __cplusplus
extern "C" {
#endif

SentryStacktraceBuilder *_Nonnull sentryDefaultThreadInspectorCreateStacktraceBuilder(
    NSArray<NSString *> *_Nonnull inAppIncludes);

#if !SDK_V10
typedef struct SentryDefaultThreadInspectorThreadInfoBuffer
    SentryDefaultThreadInspectorThreadInfoBuffer;

SentryDefaultThreadInspectorThreadInfoBuffer *_Nullable sentryDefaultThreadInspectorCaptureThreads(
    void);

void sentryDefaultThreadInspectorFreeThreadInfoBuffer(
    SentryDefaultThreadInspectorThreadInfoBuffer *_Nullable buffer);

unsigned int sentryDefaultThreadInspectorGetThreadCount(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer);

SentryCrashThread sentryDefaultThreadInspectorGetCurrentThread(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer);

SentryCrashThread sentryDefaultThreadInspectorGetThread(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index);

SentryCrashStackEntry *_Nonnull sentryDefaultThreadInspectorGetStackEntries(
    SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index);

unsigned int sentryDefaultThreadInspectorGetStackLength(
    const SentryDefaultThreadInspectorThreadInfoBuffer *_Nonnull buffer, unsigned int index);

#endif // !SDK_V10

#ifdef __cplusplus
}
#endif
