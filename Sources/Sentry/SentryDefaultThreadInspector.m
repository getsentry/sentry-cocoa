#import "SentryDefaultThreadInspector.h"
#import "SentryCrashStackEntryMapper.h"
#import "SentryStacktraceBuilder.h"
#import "SentrySwift.h"

// Model construction is always outside the C capture suspension window.
SentryStacktraceBuilder *_Nonnull sentryDefaultThreadInspectorCreateStacktraceBuilder(
    NSArray<NSString *> *_Nonnull inAppIncludes)
{
    SentryInAppLogic *inAppLogic = [[SentryInAppLogic alloc] initWithInAppIncludes:inAppIncludes];
    SentryCrashStackEntryMapper *crashStackEntryMapper =
        [[SentryCrashStackEntryMapper alloc] initWithInAppLogic:inAppLogic];
    return [[SentryStacktraceBuilder alloc] initWithCrashStackEntryMapper:crashStackEntryMapper];
}
