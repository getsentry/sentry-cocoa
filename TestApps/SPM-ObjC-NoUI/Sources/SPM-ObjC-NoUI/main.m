// Import the individual header first: a module map or umbrella must not be needed to hide AppKit.
#import <SentryWithoutUIKit/SentryCrashExceptionApplication.h>
#import <SentryWithoutUIKit/SentryWithoutUIKit.h>

#if SENTRY_HAS_UIKIT || SENTRY_TARGET_MACOS_HAS_UI || SENTRY_TARGET_REPLAY_SUPPORTED
#    error A no-UI framework must not expose UI features
#endif

// A declaration for the unavailable Objective-C class would conflict with this typedef.
typedef void SentryCrashExceptionApplication;

int
main(void)
{
    return SentryVersionNumber > 0 && SentryVersionString[0] != '\0' ? 0 : 1;
}
