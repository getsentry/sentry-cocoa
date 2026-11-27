#import <Foundation/Foundation.h>
@import Sentry;

int
main(void)
{
    @autoreleasepool {
        if ([[SentryId alloc] init].sentryIdString.length != 32 || SentryVersionNumber <= 0) {
            fprintf(stderr, "Objective-C SDK API or version export failed\n");
            return EXIT_FAILURE;
        }

        if (![[NSBundle bundleForClass:[SentrySDKLog class]] isEqual:NSBundle.mainBundle]) {
            fprintf(stderr, "Expected Sentry to be linked into the executable\n");
            return EXIT_FAILURE;
        }

        // A direct symbol reference to the category's object would mask a missing category.
        if (![NSData instancesRespondToSelector:NSSelectorFromString(@"asInputStream")]) {
            fprintf(stderr, "Static SDK is missing the NSData category\n");
            return EXIT_FAILURE;
        }

        return EXIT_SUCCESS;
    }
}
