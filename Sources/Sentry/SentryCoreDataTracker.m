
#import "SentryCoreDataTracker.h"
#import "SentryHub+Private.h"
#import "SentryLog.h"
#import "SentrySDK+Private.h"
#import "SentryScope+Private.h"
#import "SentrySpanProtocol.h"

@implementation SentryCoreDataTracker

- (NSArray *)managedObjectContext:(NSManagedObjectContext *)context
              executeFetchRequest:(NSFetchRequest *)request
                            error:(NSError **)error
                      originalImp:(NSArray *(NS_NOESCAPE ^)(NSFetchRequest *, NSError **))original
{
    __block id<SentrySpan> fetchSpan;
    [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
        fetchSpan = [span startChildWithOperation:SENTRY_COREDATA_FETCH_OPERATION
                                      description:[self descriptionFromRequest:request]];
    }];
    NSArray *result = original(request, error);

    [fetchSpan setDataValue:[NSNumber numberWithInteger:result.count] forKey:@"read_count"];

    [fetchSpan
        finishWithStatus:error != nil ? kSentrySpanStatusInternalError : kSentrySpanStatusOk];

    return result;
}

- (BOOL)managedObjectContext:(NSManagedObjectContext *)context
                        save:(NSError **)error
                 originalImp:(BOOL(NS_NOESCAPE ^)(NSError **))original
{

    __block id<SentrySpan> fetchSpan = nil;
    if (context.hasChanges) {
        __block NSDictionary<NSString *, NSDictionary *> *operations =
            [self groupEntitiesOperations:context];

        [SentrySDK.currentHub.scope useSpan:^(id<SentrySpan> _Nullable span) {
            fetchSpan = [span startChildWithOperation:SENTRY_COREDATA_SAVE_OPERATION
                                          description:[self descriptionForOperations:operations
                                                                           inContext:context]];

            [fetchSpan setDataValue:operations forKey:@"operations"];
        }];
    }

    BOOL result = original(error);

    [fetchSpan
        finishWithStatus:*error != nil ? kSentrySpanStatusInternalError : kSentrySpanStatusOk];

    return result;
}

- (NSString *)descriptionForOperations:
                  (NSDictionary<NSString *, NSDictionary<NSString *, NSNumber *> *> *)operations
                             inContext:(NSManagedObjectContext *)context
{
    __block NSMutableArray *resultParts = [NSMutableArray new];

    void (^operationInfo)(NSUInteger, NSString *) = ^void(NSUInteger total, NSString *op) {
        NSDictionary *itens = operations[op];
        if (itens && itens.count > 0) {
            if (itens.count == 1) {
                [resultParts addObject:[NSString stringWithFormat:@"%@ %@ '%@'", op,
                                                 itens.allValues[0], itens.allKeys[0]]];
            } else {
                [resultParts addObject:[NSString stringWithFormat:@"%@ %lu items", op,
                                                 (unsigned long)total]];
            }
        }
    };

    operationInfo(context.insertedObjects.count, @"INSERTED");
    operationInfo(context.updatedObjects.count, @"UPDATED");
    operationInfo(context.deletedObjects.count, @"DELETED");

    return [resultParts componentsJoinedByString:@", "];
}

- (NSDictionary<NSString *, NSDictionary *> *)groupEntitiesOperations:
    (NSManagedObjectContext *)context
{
    NSMutableDictionary<NSString *, NSDictionary *> *operations =
        [[NSMutableDictionary alloc] initWithCapacity:3];

    if (context.insertedObjects.count > 0)
        [operations setValue:[self countEntities:context.insertedObjects] forKey:@"INSERTED"];
    if (context.updatedObjects.count > 0)
        [operations setValue:[self countEntities:context.updatedObjects] forKey:@"UPDATED"];
    if (context.deletedObjects.count > 0)
        [operations setValue:[self countEntities:context.deletedObjects] forKey:@"DELETED"];

    return operations;
}

- (NSDictionary<NSString *, NSNumber *> *)countEntities:(NSSet *)entities
{
    NSMutableDictionary<NSString *, NSNumber *> *result = [NSMutableDictionary new];

    for (id item in entities) {
        NSString *cl = NSStringFromClass([item class]);
        NSNumber *count = result[cl];
        result[cl] = [NSNumber numberWithInt:count.intValue + 1];
    }

    return result;
}

- (NSString *)descriptionFromRequest:(NSFetchRequest *)request
{
    NSMutableString *result =
        [[NSMutableString alloc] initWithFormat:@"SELECT '%@'", request.entityName];

    if (request.predicate) {
        [result appendFormat:@" WHERE %@", [self predicateDescription:request.predicate]];
    }

    if (request.sortDescriptors.count > 0) {
        [result appendFormat:@" SORT BY %@", [self sortDescription:request.sortDescriptors]];
    }

    return result;
}

- (NSString *)predicateDescription:(NSPredicate *)predicate
{
    return predicate.predicateFormat;
}

- (NSString *)sortDescription:(NSArray<NSSortDescriptor *> *)sortList
{
    NSMutableArray<NSString *> *fields = [[NSMutableArray alloc] initWithCapacity:sortList.count];
    for (NSSortDescriptor *descriptor in sortList) {
        NSString *direction = descriptor.ascending ? @"" : @" DESCENDING";
        [fields addObject:[NSString stringWithFormat:@"%@%@", descriptor.key, direction]];
    }
    return [fields componentsJoinedByString:@", "];
}

@end
