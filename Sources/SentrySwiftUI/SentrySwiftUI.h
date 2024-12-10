#import <Foundation/Foundation.h>

//! Project version number for SentryUI.
FOUNDATION_EXPORT double SentryUIVersionNumber;

//! Project version string for SentryUI.
FOUNDATION_EXPORT const unsigned char SentryUIVersionString[];

extern NSString *const SENTRY_XCODE_PREVIEW_ENVIRONMENT_KEY;

#if __has_include("SentryInternal.h")
#    import "SentryInternal.h"
#endif
