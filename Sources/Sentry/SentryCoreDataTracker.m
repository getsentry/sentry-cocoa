
#import "SentryCoreDataTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpanProtocol.h"

@implementation SentryCoreDataTracker

- (NSArray *) managedObjectContext:(NSManagedObjectContext *)context
              executeFetchRequest:(NSFetchRequest *)request
                            error:(NSError **)error
                      originalImp:(NSArray * (NS_NOESCAPE ^)(NSFetchRequest *, NSError **))original
{
    __block id<SentrySpan> fetchSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        fetchSpan = [span startChildWithOperation:@"db.query"
                                      description:[self descriptionFromRequest:request]];
    }];
    NSArray *result = original(request, error);

    [fetchSpan setDataValue:[NSNumber numberWithInteger:result.count] forKey:@"result_amount"];

    [fetchSpan finishWithStatus: error != nil ? kSentrySpanStatusInternalError : kSentrySpanStatusOk ];

    return result;
}

- (BOOL) managedObjectContext:(NSManagedObjectContext *)context
                        save:(NSError **)error
                 originalImp:(BOOL (NS_NOESCAPE ^)(NSError **))original {
    
    __block id<SentrySpan> fetchSpan = nil;
    if (context.hasChanges) {
        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
            fetchSpan = [span startChildWithOperation:@"db.transaction"
                                          description:@"Saving Database"];
        }];
    }

    BOOL result = original(error);

    [fetchSpan finishWithStatus: *error != nil ? kSentrySpanStatusInternalError : kSentrySpanStatusOk ];

    return result;
}

- (NSString *)descriptionFromRequest:(NSFetchRequest *)request
{
    NSMutableString* result = [[NSMutableString alloc] initWithFormat:@"FETCH '%@'", request.entityName ];
    
    if (request.predicate) {
        [result appendFormat:@" WHERE %@", [self predicateDescription:request.predicate]];
    }
    
    if (request.sortDescriptors.count > 0) {
        [result appendFormat:@" SORT BY %@", [self sortDescription:request.sortDescriptors]];
    }
    
    return result;
}

- (NSString *)predicateDescription:(NSPredicate *)predicate {
    return predicate.predicateFormat;
}

- (NSString *)sortDescription:(NSArray<NSSortDescriptor *> *)sortList
{
    NSMutableArray<NSString *> * fields = [NSMutableArray new];
    for (NSSortDescriptor* descriptor in sortList) {
        NSString * direction = descriptor.ascending ? @"" : @" DESCENDING";
        [fields addObject:[NSString stringWithFormat:@"%@%@",descriptor.key, direction]];
    }
    return [fields componentsJoinedByString:@", "];
}

@end
