#import "SentryProfilerTestHelpers.h"

#if SENTRY_TARGET_PROFILING_SUPPORTED

#    import "SentryFileManager.h"
#    import "SentryInternalDefines.h"
#    import "SentryLaunchProfiling.h"
#    import "SentrySerialization.h"

BOOL
sentry_threadSanitizerIsPresent(void)
{
#    if defined(__has_feature)
#        if __has_feature(thread_sanitizer)
    return YES;
#            pragma clang diagnostic push
#            pragma clang diagnostic ignored "-Wunreachable-code"
#        endif // __has_feature(thread_sanitizer)
#    endif // defined(__has_feature)

    return NO;
}

#    if defined(TEST) || defined(TESTCI) || defined(DEBUG)

void
sentry_writeProfileFile(NSDictionary<NSString *, id> *payload)
{
    NSData *data = [SentrySerialization dataWithJSONObject:payload];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *appSupportDirPath = sentryApplicationSupportPath();

    if (![fm fileExistsAtPath:appSupportDirPath]) {
        SENTRY_LOG_DEBUG(@"Creating app support directory.");
        NSError *error;
        if (!SENTRY_CASSERT_RETURN([fm createDirectoryAtPath:appSupportDirPath
                                       withIntermediateDirectories:NO
                                                        attributes:nil
                                                             error:&error],
                @"Failed to create sentry app support directory")) {
            return;
        }
    } else {
        SENTRY_LOG_DEBUG(@"App support directory already exists.");
    }

    NSString *pathToWrite;
    if (sentry_isTracingAppLaunch) {
        SENTRY_LOG_DEBUG(@"Writing app launch profile.");
        pathToWrite = [appSupportDirPath stringByAppendingPathComponent:@"launchProfile"];
    } else {
        SENTRY_LOG_DEBUG(@"Overwriting last non-launch profile.");
        pathToWrite = [appSupportDirPath stringByAppendingPathComponent:@"profile"];
    }

    if ([fm fileExistsAtPath:pathToWrite]) {
        SENTRY_LOG_DEBUG(@"Already a %@ profile file present; make sure to remove them right after "
                         @"using them, and that tests clean state in between so there isn't "
                         @"leftover config producing one when it isn't expected.",
            sentry_isTracingAppLaunch ? @" launch" : @"");
        return;
    }

    SENTRY_LOG_DEBUG(@"Writing%@ profile to file.", sentry_isTracingAppLaunch ? @" launch" : @"");

    NSError *error;
    if (![data writeToFile:pathToWrite options:NSDataWritingAtomic error:&error]) {
        SENTRY_LOG_ERROR(@"Failed to write data to path %@: %@", pathToWrite, error);
    }
}

#    endif // defined(TEST) || defined(TESTCI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED
