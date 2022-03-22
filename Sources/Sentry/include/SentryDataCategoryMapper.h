#import "SentryDataCategory.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(DataCategoryMapper)
@interface SentryDataCategoryMapper : NSObject

/** Maps an event type to the category for rate limiting.
 */
+ (SentryDataCategory)mapEventTypeToCategory:(NSString *)eventType;

+ (SentryDataCategory)mapEnvelopeItemTypeToCategory:(NSString *)itemType;

+ (SentryDataCategory)mapIntegerToCategory:(NSUInteger)value;

@end

NS_ASSUME_NONNULL_END
