#import "SentryDefines.h"
#import <Foundation/Foundation.h>

#if SENTRY_HAS_UIKIT

NS_ASSUME_NONNULL_BEGIN

@interface SentryViewHierarchy : NSObject

+ (void)fetchViewHierarchy;
@end

NS_ASSUME_NONNULL_END
#endif
