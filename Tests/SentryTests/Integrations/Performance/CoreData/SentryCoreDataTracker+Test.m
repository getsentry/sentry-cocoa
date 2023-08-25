#import "SentryCoreDataTracker+Test.h"

@implementation
SentryCoreDataTracker (Test)

- (BOOL)saveManagedObjectContextWithNilError:(NSManagedObjectContext *)context
                                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original
{
    return [self managedObjectContext:context save:nil originalImp:original];
}

@end
