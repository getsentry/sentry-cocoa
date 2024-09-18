#import "SentryCoreDataTracker.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface
SentryCoreDataTracker (Test)

- (BOOL)saveManagedObjectContextWithNilError:(NSManagedObjectContext *)context
                                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original;

@end

NS_ASSUME_NONNULL_END
