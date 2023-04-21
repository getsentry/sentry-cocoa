#import "SentryBaseIntegration.h"
#import "SentryClient+Private.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
#if SENTRY_HAS_UIKIT

@interface SentryViewHierarchyIntegration : SentryBaseIntegration <SentryClientAttachmentProcessor>

@end

#endif

NS_ASSUME_NONNULL_END
