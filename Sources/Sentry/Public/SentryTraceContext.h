// SentryTraceContext is implemented in Swift (TraceContext).
// This header stays so existing `#import <Sentry/SentryTraceContext.h>` and quoted
// includes keep compiling. It has no @interface: declaring the class here would
// duplicate the Swift type. Code that needs the real type imports the Swift
// declaration (SentrySwift.h for Objective-C).
