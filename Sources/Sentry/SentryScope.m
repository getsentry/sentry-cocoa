#import "NSMutableDictionary+Sentry.h"
#import "SentryAttachment+Private.h"
#import "SentryBreadcrumb.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent+Private.h"
#import "SentryLevelMapper.h"
#import "SentryLogC.h"
#import "SentryModels+Serializable.h"
#import "SentryPropagationContext.h"
#import "SentryScope+Private.h"
#import "SentryScope+PrivateSwift.h"
#import "SentryScopeObserver.h"
#import "SentrySession.h"
#import "SentrySpan.h"
#import "SentrySwift.h"
#import "SentryTracer.h"
#import "SentryTransactionContext.h"
#import "SentryUser+Serialize.h"
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryScope ()

@property (atomic) NSUInteger maxBreadcrumbs;
@property (atomic) NSUInteger currentBreadcrumbIndex;

@property (atomic, strong) NSMutableArray<SentryAttachment *> *attachmentArray;

@property (nonatomic, retain) NSMutableArray<id<SentryScopeObserver>> *observers;

@property (atomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;

@end

@implementation SentryScope {
    NSObject *_spanLock;
}

@synthesize span = _span;

#pragma mark Initializer

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        _maxBreadcrumbs = MAX(0, maxBreadcrumbs);
        _currentBreadcrumbIndex = 0;
        _breadcrumbArray = [[NSMutableArray alloc] initWithCapacity:_maxBreadcrumbs];
        self.tagDictionary = [NSMutableDictionary new];
        self.extraDictionary = [NSMutableDictionary new];
        self.contextDictionary = [NSMutableDictionary new];
        self.attachmentArray = [NSMutableArray new];
        self.fingerprintArray = [NSMutableArray new];
        _spanLock = [[NSObject alloc] init];
        self.observers = [NSMutableArray new];
        self.propagationContext = [[SentryPropagationContext alloc] init];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithMaxBreadcrumbs:defaultMaxBreadcrumbs];
}

- (instancetype)initWithScope:(SentryScope *)scope
{
    if (self = [self init]) {
        [_extraDictionary addEntriesFromDictionary:[scope extras]];
        [_tagDictionary addEntriesFromDictionary:[scope tags]];
        [_contextDictionary addEntriesFromDictionary:[scope context]];
        NSArray<SentryBreadcrumb *> *crumbs = [scope breadcrumbs];
        _breadcrumbArray = [[NSMutableArray alloc] initWithCapacity:scope.maxBreadcrumbs];
        _currentBreadcrumbIndex = crumbs.count;
        [_breadcrumbArray addObjectsFromArray:crumbs];
        [_fingerprintArray addObjectsFromArray:[scope fingerprints]];
        [_attachmentArray addObjectsFromArray:[scope attachments]];

        self.propagationContext = scope.propagationContext;
        self.maxBreadcrumbs = scope.maxBreadcrumbs;
        self.userObject = scope.userObject.copy;
        self.distString = scope.distString;
        self.environmentString = scope.environmentString;
        self.levelEnum = scope.levelEnum;
        self.span = scope.span;
        self.replayId = scope.replayId;
    }
    return self;
}

#pragma mark Global properties

- (void)add:(SentryBreadcrumb *)crumb
{
    [self addBreadcrumb:crumb];
}

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    if (self.maxBreadcrumbs < 1) {
        return;
    }
    SENTRY_LOG_DEBUG(@"Add breadcrumb: %@", crumb);
    @synchronized(_breadcrumbArray) {
        // Use a ring buffer making adding breadcrumbs O(1).
        // In a prior version, we added the new breadcrumb at the end of the array and used
        // removeObjectAtIndex:0 when reaching the max breadcrumb amount. removeObjectAtIndex:0 is
        // O(n) because it needs to reshift the whole array. So when the breadcrumbs array was full
        // every add operation was O(n).

        _breadcrumbArray[_currentBreadcrumbIndex] = crumb;

        _currentBreadcrumbIndex = (_currentBreadcrumbIndex + 1) % _maxBreadcrumbs;

        // Serializing is expensive. Only do it once.
        NSDictionary<NSString *, id> *serializedBreadcrumb = [crumb serialize];
        for (id<SentryScopeObserver> observer in self.observers) {
            [observer addSerializedBreadcrumb:serializedBreadcrumb];
        }
    }
}

- (void)setSpan:(nullable id<SentrySpan>)span
{
    @synchronized(_spanLock) {
        _span = span;

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTraceContext:[self buildTraceContext:span]];
        }
    }
}

- (void)setPropagationContext:(SentryPropagationContext *)propagationContext
{
    @synchronized(_propagationContext) {
        _propagationContext = propagationContext;

        if (self.observers.count > 0) {
            NSDictionary *traceContext = [self.propagationContext traceContextForEvent];
            for (id<SentryScopeObserver> observer in self.observers) {
                [observer setTraceContext:traceContext];
            }
        }
    }
}

- (nullable id<SentrySpan>)span
{
    @synchronized(_spanLock) {
        return _span;
    }
}

- (void)useSpan:(SentrySpanCallback)callback
{
    id<SentrySpan> localSpan = [self span];
    callback(localSpan);
}

- (void)clear
{
    // As we need to synchronize the accesses of the arrays and dictionaries and we use the
    // references instead of self we remove all objects instead of creating new instances. Removing
    // all objects is usually O(n). This is acceptable as we don't expect a huge amount of elements
    // in the arrays or dictionaries, that would slow down the performance.
    [self clearBreadcrumbs];
    @synchronized(_tagDictionary) {
        [_tagDictionary removeAllObjects];
    }
    @synchronized(_extraDictionary) {
        [_extraDictionary removeAllObjects];
    }
    @synchronized(_contextDictionary) {
        [_contextDictionary removeAllObjects];
    }
    @synchronized(_fingerprintArray) {
        [_fingerprintArray removeAllObjects];
    }
    [self clearAttachments];
    @synchronized(_spanLock) {
        _span = nil;
    }

    self.userObject = nil;
    self.distString = nil;
    self.environmentString = nil;
    self.levelEnum = kSentryLevelNone;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer clear];
    }
}

- (void)clearBreadcrumbs
{
    @synchronized(_breadcrumbArray) {
        _currentBreadcrumbIndex = 0;
        [_breadcrumbArray removeAllObjects];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer clearBreadcrumbs];
        }
    }
}

- (NSArray<SentryBreadcrumb *> *)breadcrumbs
{
    NSMutableArray<SentryBreadcrumb *> *crumbs = [NSMutableArray new];
    @synchronized(_breadcrumbArray) {
        for (int i = 0; i < _maxBreadcrumbs; i++) {
            // Crumbs use a ring buffer. We need to start at the current crumb to get the
            // crumbs in the correct order.
            NSInteger index = (_currentBreadcrumbIndex + i) % _maxBreadcrumbs;

            if (index < _breadcrumbArray.count) {
                [crumbs addObject:_breadcrumbArray[index]];
            }
        }
    }

    return crumbs;
}

- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key
{
    @synchronized(_contextDictionary) {
        [_contextDictionary setValue:value forKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setContext:_contextDictionary];
        }
    }
}

- (nullable NSDictionary<NSString *, id> *)getContextForKey:(NSString *)key
{
    @synchronized(_contextDictionary) {
        return [_contextDictionary objectForKey:key];
    }
}

- (void)removeContextForKey:(NSString *)key
{
    @synchronized(_contextDictionary) {
        [_contextDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setContext:_contextDictionary];
        }
    }
}

- (NSDictionary<NSString *, NSDictionary<NSString *, id> *> *)context
{
    @synchronized(_contextDictionary) {
        return _contextDictionary.copy;
    }
}

- (void)setExtraValue:(id _Nullable)value forKey:(NSString *)key
{
    @synchronized(_extraDictionary) {
        [_extraDictionary setValue:value forKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (void)removeExtraForKey:(NSString *)key
{
    @synchronized(_extraDictionary) {
        [_extraDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras
{
    if (extras == nil) {
        return;
    }
    @synchronized(_extraDictionary) {
        [_extraDictionary addEntriesFromDictionary:extras];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setExtras:_extraDictionary];
        }
    }
}

- (NSDictionary<NSString *, id> *)extras
{
    @synchronized(_extraDictionary) {
        return _extraDictionary.copy;
    }
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(_tagDictionary) {
        _tagDictionary[key] = value;

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(_tagDictionary) {
        [_tagDictionary removeObjectForKey:key];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags
{
    if (tags == nil) {
        return;
    }
    @synchronized(_tagDictionary) {
        [_tagDictionary addEntriesFromDictionary:tags];

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setTags:_tagDictionary];
        }
    }
}

- (NSDictionary<NSString *, NSString *> *)tags
{
    @synchronized(_tagDictionary) {
        return _tagDictionary.copy;
    }
}

- (void)setUser:(SentryUser *_Nullable)user
{
    @synchronized(self) {
        self.userObject = user;

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setUser:user];
        }
    }
}

- (void)setDist:(NSString *_Nullable)dist
{
    self.distString = dist;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setDist:dist];
    }
}

- (void)setEnvironment:(NSString *_Nullable)environment
{
    self.environmentString = environment;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setEnvironment:environment];
    }
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint
{
    @synchronized(_fingerprintArray) {
        [_fingerprintArray removeAllObjects];
        if (fingerprint != nil) {
            [_fingerprintArray addObjectsFromArray:fingerprint];
        }

        for (id<SentryScopeObserver> observer in self.observers) {
            [observer setFingerprint:_fingerprintArray];
        }
    }
}

- (NSArray<NSString *> *)fingerprints
{
    @synchronized(_fingerprintArray) {
        return _fingerprintArray.copy;
    }
}

- (void)setCurrentScreen:(nullable NSString *)currentScreen
{
    _currentScreen = currentScreen;

    SEL setCurrentScreen = @selector(setCurrentScreen:);
    for (id<SentryScopeObserver> observer in self.observers) {
        if ([observer respondsToSelector:setCurrentScreen]) {
            [observer setCurrentScreen:currentScreen];
        }
    }
}

- (void)setLevel:(enum SentryLevel)level
{
    self.levelEnum = level;

    for (id<SentryScopeObserver> observer in self.observers) {
        [observer setLevel:level];
    }
}

- (void)includeAttachment:(SentryAttachment *)attachment
{
    [self addAttachment:attachment];
}

- (void)addAttachment:(SentryAttachment *)attachment
{
    @synchronized(_attachmentArray) {
        [_attachmentArray addObject:attachment];
    }
}

- (void)addCrashReportAttachmentInPath:(NSString *)filePath
{
    if ([filePath.lastPathComponent isEqualToString:@"view-hierarchy.json"]) {
        [self addAttachment:[[SentryAttachment alloc]
                                  initWithPath:filePath
                                      filename:@"view-hierarchy.json"
                                   contentType:@"application/json"
                                attachmentType:kSentryAttachmentTypeViewHierarchy]];
    } else {
        [self addAttachment:[[SentryAttachment alloc] initWithPath:filePath]];
    }
}

- (void)clearAttachments
{
    @synchronized(_attachmentArray) {
        [_attachmentArray removeAllObjects];
    }
}

- (NSArray<SentryAttachment *> *)attachments
{
    @synchronized(_attachmentArray) {
        return _attachmentArray.copy;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    if (self.tags.count > 0) {
        [serializedData setValue:[self tags] forKey:@"tags"];
    }
    if (self.extras.count > 0) {
        [serializedData setValue:[self extras] forKey:@"extra"];
    }

    NSDictionary *traceContext = nil;
    id<SentrySpan> span = nil;

    if (self.span != nil) {
        @synchronized(_spanLock) {
            span = self.span;
        }
    }
    traceContext = [self buildTraceContext:span];
    serializedData[@"traceContext"] = traceContext;

    NSDictionary *context = [self context];
    if (context.count > 0) {
        [serializedData setValue:context forKey:@"context"];
    }

    [serializedData setValue:[self.userObject serialize] forKey:@"user"];
    [serializedData setValue:self.distString forKey:@"dist"];
    [serializedData setValue:self.environmentString forKey:@"environment"];
    [serializedData setValue:self.replayId forKey:@"replay_id"];
    if (self.fingerprints.count > 0) {
        [serializedData setValue:[self fingerprints] forKey:@"fingerprint"];
    }

    SentryLevel level = self.levelEnum;
    if (level != kSentryLevelNone) {
        [serializedData setValue:nameForSentryLevel(level) forKey:@"level"];
    }
    NSArray *crumbs = [self serializeBreadcrumbs];
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    return serializedData;
}

- (NSArray *)serializeBreadcrumbs
{
    NSMutableArray *serializedCrumbs = [NSMutableArray new];

    NSArray<SentryBreadcrumb *> *crumbs = [self breadcrumbs];
    for (SentryBreadcrumb *crumb in crumbs) {
        [serializedCrumbs addObject:[crumb serialize]];
    }

    return serializedCrumbs;
}

- (void)applyToSession:(SentrySession *)session
{
    SentryUser *userObject = self.userObject;
    if (userObject != nil) {
        session.user = userObject.copy;
    }

    NSString *environment = self.environmentString;
    if (environment != nil) {
        // TODO: Make sure environment set on options is applied to the
        // scope so it's available now
        session.environment = environment;
    }
}

- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs
{
    if (event.isFatalEvent) {
        SENTRY_LOG_WARN(@"Won't apply scope to a crash event. This is not allowed as crash "
                        @"events are from a previous run of the app and the current scope might "
                        @"have different data than the scope that was active during the crash.");
        return event;
    }

    if (event.tags == nil) {
        event.tags = [self tags];
    } else {
        NSMutableDictionary *newTags = [NSMutableDictionary new];
        [newTags addEntriesFromDictionary:[self tags]];
        [newTags addEntriesFromDictionary:event.tags];
        event.tags = newTags;
    }

    if (event.extra == nil) {
        event.extra = [self extras];
    } else {
        NSMutableDictionary *newExtra = [NSMutableDictionary new];
        [newExtra addEntriesFromDictionary:[self extras]];
        [newExtra addEntriesFromDictionary:event.extra];
        event.extra = newExtra;
    }

    NSArray *fingerprints = [self fingerprints];
    if (fingerprints.count > 0 && event.fingerprint == nil) {
        event.fingerprint = fingerprints;
    }

    if (event.breadcrumbs == nil) {
        NSArray *breadcrumbs = [self breadcrumbs];
        event.breadcrumbs = [breadcrumbs
            subarrayWithRange:NSMakeRange(0, MIN(maxBreadcrumbs, [breadcrumbs count]))];
    }

    SentryUser *user = self.userObject.copy;
    if (user != nil) {
        event.user = user;
    }

    NSString *dist = self.distString;
    if (dist != nil && event.dist == nil) {
        // dist can also be set via options but scope takes precedence.
        event.dist = dist;
    }

    NSString *environment = self.environmentString;
    if (environment != nil && event.environment == nil) {
        // environment can also be set via options but scope takes
        // precedence.
        event.environment = environment;
    }

    SentryLevel level = self.levelEnum;
    if (level != kSentryLevelNone) {
        // We always want to set the level from the scope since this has
        // been set on purpose
        event.level = level;
    }

    id<SentrySpan> span;

    if (self.span != nil) {
        @synchronized(_spanLock) {
            span = self.span;
        }

        // Span could be nil as we do the first check outside the synchronize
        if (span != nil) {
            if (![event.type isEqualToString:SentryEnvelopeItemTypeTransaction] &&
                [span isKindOfClass:[SentryTracer class]]) {
                event.transaction = [[(SentryTracer *)span transactionContext] name];
            }
        }
    }

    NSMutableDictionary *newContext = [self context].mutableCopy;
    if (event.context != nil) {
        [SentryDictionary mergeEntriesFromDictionary:event.context intoDictionary:newContext];
    }

    newContext[@"trace"] = [self buildTraceContext:span];

    event.context = newContext;
    return event;
}

- (void)addObserver:(id<SentryScopeObserver>)observer
{
    [self.observers addObject:observer];
}

- (NSDictionary *)buildTraceContext:(nullable id<SentrySpan>)span
{
    if (span != nil) {
        return [span serialize];
    } else {
        return [self.propagationContext traceContextForEvent];
    }
}

- (NSString *)propagationContextTraceIdString
{
    return [self.propagationContext.traceId sentryIdString];
}

@end

NS_ASSUME_NONNULL_END
