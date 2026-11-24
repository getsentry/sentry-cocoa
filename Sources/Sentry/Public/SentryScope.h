// SentryScope is implemented in Swift (`Scope`).
// This header stays so existing `#import <Sentry/SentryScope.h>` and
// `#import <SentryWithoutUIKit/SentryScope.h>` keep compiling.
// It declares no interface, because declaring the class here would duplicate
// the Swift type. Use `@import Sentry;` to get the class declaration.
