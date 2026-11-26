#import <Foundation/Foundation.h>
@import Sentry;

int
main(void)
{
    @autoreleasepool {
        // Exercise either producer's binary without starting integrations or sending network
        // requests.
#if !SENTRY_TEST_V10
        [SentrySDK close];
#endif
        if (!(SentryVersionNumber > 0 && SentryVersionString[0] != '\0' &&
                [SentrySDKLog willLogAtLevel:kSentryLevelFatal] &&
                [[SentryId alloc] init].sentryIdString.length == 32)) {
            fprintf(stderr, "Objective-C SDK API or version exports failed\n");
            return EXIT_FAILURE;
        }

        // Inspect the bundle containing the loaded SDK code, not an unused framework copy.
        NSBundle *framework = [NSBundle bundleForClass:[SentrySDKLog class]];
        if (![framework.bundleURL.lastPathComponent isEqualToString:@"Sentry.framework"]) {
            fprintf(stderr, "Sentry must be dynamically loaded from Sentry.framework\n");
            return EXIT_FAILURE;
        }

        printf("Dynamic Objective-C SDK: public API, version exports and dynamic loading passed\n");
        return EXIT_SUCCESS;
    }
}
