#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Used to transforms a NSPredicate into a human friendly string.
 * This class is used for CoreData and omits variable values
 * and don't convert CoreData not supported instructions.
 */
@interface SentryPredicateDescriptor : NSObject

- (NSString *)predicateDescription:(NSPredicate *)predicate;

@end

NS_ASSUME_NONNULL_END
