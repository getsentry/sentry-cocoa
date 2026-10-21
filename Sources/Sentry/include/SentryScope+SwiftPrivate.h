#import "SentryDefines.h"
#import "SentryScope.h"

NS_ASSUME_NONNULL_BEGIN

// Event is a Swift class, so these declarations use id. The typed Swift name
// applyTo(event:maxBreadcrumbs:) lives in a Swift extension that casts the result.

@interface SentryScope (SwiftPrivate)

- (nullable SENTRY_SWIFT_MIGRATION_ID(SentryEvent))applyToEvent:(nullable SENTRY_SWIFT_MIGRATION_ID(
                                                                    SentryEvent))event
                                                  maxBreadcrumb:(NSUInteger)maxBreadcrumbs
    NS_SWIFT_NAME(applyToEvent(_:maxBreadcrumb:));

- (void)overlayOnEvent:(SENTRY_SWIFT_MIGRATION_ID(SentryEvent))event
         maxBreadcrumb:(NSUInteger)maxBreadcrumbs NS_SWIFT_NAME(overlay(on:maxBreadcrumb:));

@end

NS_ASSUME_NONNULL_END
