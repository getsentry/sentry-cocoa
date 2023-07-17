#import "SentryCoreDataTracker+Test.h"
#import <Foundation/Foundation.h>

@implementation
SentryCoreDataTracker (Test)

- (BOOL)saveManagedObjectContextWithNilError:(NSManagedObjectContext *)context
                                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original
{
    return [self managedObjectContext:context save:nil originalImp:original];
}

@end
