#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class SentryBreadcrumb;

/**
 * This is a workaround to access SentryLevel value from swift
 */
@interface SentryLevelHelper : NSObject

+ (NSString *_Nonnull)breadcrumbLevel:(SentryBreadcrumb *)breadcrumb;

@end

NS_ASSUME_NONNULL_END
