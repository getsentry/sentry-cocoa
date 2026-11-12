#include "SentryThreadSnapshot.h"
#import <Foundation/Foundation.h>

@class SentryStacktraceBuilder;

#ifdef __cplusplus
extern "C" {
#endif

SentryStacktraceBuilder *_Nonnull sentryDefaultThreadInspectorCreateStacktraceBuilder(
    NSArray<NSString *> *_Nonnull inAppIncludes);

#ifdef __cplusplus
}
#endif
