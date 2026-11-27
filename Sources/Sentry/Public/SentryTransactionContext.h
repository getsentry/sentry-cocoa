// SentryTransactionContext is implemented in Swift (`TransactionContext`).
// This header stays so existing `#import <Sentry/SentryTransactionContext.h>` and
// `#import <SentryWithoutUIKit/SentryTransactionContext.h>` keep compiling.
// It declares no interface, because declaring the class here would duplicate
// the Swift type. Use `@import Sentry;` to get the class declaration.
