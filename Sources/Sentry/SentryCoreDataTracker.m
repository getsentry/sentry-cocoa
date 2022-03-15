
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
        __block NSDictionary<NSString *, NSDictionary *> *operations = @{
            @"INSERTED" : [self countEntities:context.insertedObjects],
            @"UPDATED" : [self countEntities:context.updatedObjects],
            @"DELETED" : [self countEntities:context.deletedObjects]
        };

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
    NSMutableArray *resultParts = [NSMutableArray new];

    NSDictionary<NSString *, NSNumber *> *inserts = operations[@"INSERTED"];
    if (inserts.count > 0) {
        if (inserts.count == 1) {
            [resultParts addObject:[NSString stringWithFormat:@"INSERTED %@ '%@'",
                                             inserts.allValues[0], inserts.allKeys[0]]];
        } else {
            [resultParts addObject:[NSString stringWithFormat:@"INSERTED %lu itens",
                                             (unsigned long)context.insertedObjects.count]];
        }
    }

    NSDictionary<NSString *, NSNumber *> *updates = operations[@"UPDATED"];
    if (updates.count > 0) {
        if (updates.count == 1) {
            [resultParts addObject:[NSString stringWithFormat:@"UPDATED %@ '%@'",
                                             updates.allValues[0], updates.allKeys[0]]];
        } else {
            [resultParts addObject:[NSString stringWithFormat:@"UPDATED %lu itens",
                                             (unsigned long)context.updatedObjects.count]];
        }
    }

    NSDictionary<NSString *, NSNumber *> *deletes = operations[@"DELETED"];
    if (deletes.count > 0) {
        if (deletes.count == 1) {
            [resultParts addObject:[NSString stringWithFormat:@"DELETED %@ '%@'",
                                             deletes.allValues[0], deletes.allKeys[0]]];
        } else {
            [resultParts addObject:[NSString stringWithFormat:@"DELETED %lu itens",
                                             (unsigned long)context.deletedObjects.count]];
        }
    }

    return [resultParts componentsJoinedByString:@", "];
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
    NSMutableArray<NSString *> *fields = [NSMutableArray new];
    for (NSSortDescriptor *descriptor in sortList) {
        NSString *direction = descriptor.ascending ? @"" : @" DESCENDING";
        [fields addObject:[NSString stringWithFormat:@"%@%@", descriptor.key, direction]];
    }
    return [fields componentsJoinedByString:@", "];
}

@end
