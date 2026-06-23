#import <Foundation/Foundation.h>

@class SentryObjCBreadcrumb;

NS_ASSUME_NONNULL_BEGIN

/// Breadcrumb APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalBreadcrumbApi : NSObject

/// Creates a @c SentryObjCBreadcrumb from a dictionary.
- (SentryObjCBreadcrumb *)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
