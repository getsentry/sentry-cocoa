// SentryEvent is implemented in Swift (`Event`).
// This header stays so existing `#import <Sentry/SentryEvent.h>` and
// `#import <SentryWithoutUIKit/SentryEvent.h>` keep compiling.
// It declares no interface, because declaring the class here would duplicate
// the Swift type. Use `@import Sentry;` to get the class declaration.
