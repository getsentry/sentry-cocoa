// SentrySpan is implemented in Swift (`Span`).
// This header stays so existing `#import <Sentry/SentrySpanProtocol.h>` and
// `#import <SentryWithoutUIKit/SentrySpanProtocol.h>` keep compiling.
// It declares no interface, because declaring the protocol here would duplicate
// the Swift type. Use `@import Sentry;` to get the protocol declaration.
