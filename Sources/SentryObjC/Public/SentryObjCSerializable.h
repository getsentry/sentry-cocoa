#import <Foundation/Foundation.h>

#import "SentryObjCDefines.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Protocol for types that can be serialized to a dictionary.
 *
 * @see SentryScope
 * @see SentryBreadcrumb
 * @see SentryEvent
 */
@protocol SentrySerializable <NSObject>

SENTRY_NO_INIT

/**
 * Serialize the contents of the object into an NSDictionary.
 *
 * @return A dictionary representation. Modifications to the original object do not affect the
 * returned dictionary.
 */
- (NSDictionary<NSString *, id> *)serialize;

@end

NS_ASSUME_NONNULL_END
