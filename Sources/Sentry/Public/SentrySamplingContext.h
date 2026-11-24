// SentrySamplingContext is implemented in Swift (`SamplingContext`).
// This header stays so existing `#import <Sentry/SentrySamplingContext.h>` and
// `#import <SentryWithoutUIKit/SentrySamplingContext.h>` keep compiling.
// It declares no interface, because declaring the class here would duplicate
// the Swift type. Use `@import Sentry;` to get the class declaration.
