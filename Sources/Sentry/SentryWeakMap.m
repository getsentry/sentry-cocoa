#import "SentryWeakMap.h"

@interface SentryWeakMap <KeyType, ObjectType>()
@property (nonatomic, strong) NSMapTable<KeyType, ObjectType> *mapTable;
@end

@implementation SentryWeakMap

- (instancetype)init
{
    if (self = [super init]) {
        _mapTable = [NSMapTable weakToStrongObjectsMapTable];
    }
    return self;
}

- (nullable id)objectForKey:(nullable id)aKey
{
    id obj = [self.mapTable objectForKey:aKey];
    [self prune];
    return obj;
}

- (void)setObject:(nullable id)anObject forKey:(nullable id)aKey
{
    [self.mapTable setObject:anObject forKey:aKey];
    [self prune];
}

- (void)removeObjectForKey:(nullable id)aKey
{
    [self.mapTable removeObjectForKey:aKey];
    [self prune];
}

- (NSUInteger)count
{
    return self.mapTable.count;
}

- (void)prune
{
    for (id key in self.mapTable.keyEnumerator) {
        // No-op: iterating triggers internal cleanup of nil keys
        (void)key;
    }
}

@end
