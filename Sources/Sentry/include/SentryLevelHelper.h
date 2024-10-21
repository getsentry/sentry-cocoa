#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;

/**
 * This is a workaround to access SentryLevel value from swift
 */
@interface SentryLevelBridge : NSObject
+ (NSUInteger) breadcrumbLevel:(SentryBreadcrumb *)breadcrumb;
@end

NS_ASSUME_NONNULL_END
