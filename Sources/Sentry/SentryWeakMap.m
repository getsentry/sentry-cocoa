#import "SentryWeakMap.h"

// Visit more entries than one insertion appends so cleanup can catch the tail and revisit older
// entries even during sustained insertion.
static const NSUInteger SentryWeakMapCleanupBudget = 2;

@interface SentryWeakBox : NSObject <NSCopying>

@property (nonatomic, weak, readonly) id key;
@property (nonatomic, strong) id value;
// The dictionary owns every entry. Weak links avoid cycles and recursive list destruction.
@property (nonatomic, weak) SentryWeakBox *previous;
@property (nonatomic, weak) SentryWeakBox *next;

- (instancetype)initWithKey:(id)key;

@end

@implementation SentryWeakBox {
    __weak id _key;
    NSUInteger _hash;
}

- (instancetype)initWithKey:(id)key
{
    if (self = [super init]) {
        _key = key;
        // We need to cache the hash value because weak keys can be deallocated.
        // This hash is used to identify the weak box by the wrapped key in the storage.
        _hash = [key hash];
    }
    return self;
}

- (id)key
{
    return _key;
}

- (NSUInteger)hash
{
    return _hash;
}

- (BOOL)isEqual:(id)object
{
    // Cleanup must be able to remove the stored box after its key has been deallocated.
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:[SentryWeakBox class]]) {
        return NO;
    }
    id selfKey = self.key;
    id otherKey = ((SentryWeakBox *)object).key;
    return selfKey && otherKey && [selfKey isEqual:otherKey];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    // Keep the dictionary key identical to the list entry, including after the weak key dies.
    return self;
}

@end

@interface SentryWeakMap <KeyType, ObjectType>()
@property (nonatomic, strong) NSMutableDictionary<SentryWeakBox *, SentryWeakBox *> *storage;
@property (nonatomic, strong) SentryWeakBox *head;
@property (nonatomic, strong) SentryWeakBox *tail;
@property (nonatomic, strong) SentryWeakBox *pruneCursor;
@end

@implementation SentryWeakMap

// This class was originally a wrapper around NSMapTable with weak keys.
// Due to undeterministic behavior of NSMapTable, we had to implement our own weak key storage.

- (instancetype)init
{
    if (self = [super init]) {
        _storage = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)setObject:(nullable id)anObject forKey:(nullable id)aKey
{
    if (!aKey || !anObject) {
        return;
    }

    [self pruneNextEntries:SentryWeakMapCleanupBudget];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    SentryWeakBox *entry = self.storage[box];
    if (entry != nil) {
        entry.value = anObject;
        return;
    }

    box.value = anObject;
    box.previous = self.tail;
    self.tail.next = box;
    self.tail = box;
    if (self.head == nil) {
        self.head = box;
    }
    self.storage[box] = box;
}

- (nullable id)objectForKey:(nullable id)aKey
{
    if (!aKey) {
        return nil;
    }

    [self pruneNextEntries:SentryWeakMapCleanupBudget];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    return self.storage[box].value;
}

- (void)removeObjectForKey:(nullable id)aKey
{
    if (!aKey) {
        return;
    }

    [self pruneNextEntries:SentryWeakMapCleanupBudget];

    SentryWeakBox *box = [[SentryWeakBox alloc] initWithKey:aKey];
    SentryWeakBox *entry = self.storage[box];
    if (entry != nil) {
        [self removeEntry:entry];
    }
}

- (void)removeEntry:(SentryWeakBox *)entry
{
    SentryWeakBox *previous = entry.previous;
    SentryWeakBox *next = entry.next;
    previous.next = next;
    next.previous = previous;
    if (self.head == entry) {
        self.head = next;
    }
    if (self.tail == entry) {
        self.tail = previous;
    }
    if (self.pruneCursor == entry) {
        self.pruneCursor = next;
    }
    [self.storage removeObjectForKey:entry];
}

- (NSUInteger)count
{
    // Do not prune here, to make this method a direct proxy for the underlying dictionary.
    return self.storage.count;
}

- (void)pruneNextEntries:(NSUInteger)limit
{
    // The doubly linked list provides a stable cursor across dictionary mutations. Inspect a fixed
    // number of entries on ordinary accesses, rather than occasionally blocking on a full-map scan.
    NSUInteger entriesToVisit = MIN(limit, self.storage.count);
    for (NSUInteger i = 0; i < entriesToVisit; i++) {
        SentryWeakBox *entry = self.pruneCursor ?: self.head;
        self.pruneCursor = entry.next;
        if (entry.key == nil) {
            [self removeEntry:entry];
        }
    }
}

- (void)prune
{
    [self pruneNextEntries:self.storage.count];
}

@end
