// SentryTransaction is implemented in Swift (`Transaction`).
// This header stays so existing `#import <Sentry/SentryTransaction.h>` and
// `#import <SentryWithoutUIKit/SentryTransaction.h>` keep compiling.
// It declares no interface, because declaring the class here would duplicate
// the Swift type. Use `@import Sentry;` to get the class declaration.
