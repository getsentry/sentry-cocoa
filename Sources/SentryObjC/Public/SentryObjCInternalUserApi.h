#import <Foundation/Foundation.h>

@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

/// User APIs for Sentry hybrid SDKs.
///
/// These methods may change in any minor release without deprecation.
@interface SentryObjCInternalUserApi : NSObject

/// Creates a @c SentryObjCUser from a dictionary.
- (SentryObjCUser *)fromDictionary:(NSDictionary *)dictionary;

@end

NS_ASSUME_NONNULL_END
