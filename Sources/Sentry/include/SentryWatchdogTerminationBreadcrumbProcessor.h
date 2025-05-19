#import <Foundation/Foundation.h>

@class SentryFileManager;

@interface SentryWatchdogTerminationBreadcrumbProcessor : NSObject

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager;

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb;

- (void)clearBreadcrumbs;

- (void)clear;

@end
