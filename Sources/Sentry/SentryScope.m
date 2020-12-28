#import "SentryScope.h"
#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryEvent.h"
#import "SentryGlobalEventProcessor.h"
#import "SentryLog.h"
#import "SentryScope+Private.h"
#import "SentrySession.h"
#import "SentryUser.h"

NS_ASSUME_NONNULL_BEGIN

@interface
SentryScope ()

/**
 * Set global user -> thus will be sent with every event
 */
@property (atomic, strong) SentryUser *_Nullable userObject;

/**
 * Set global tags -> these will be sent with every event
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *_Nullable tagDictionary;

/**
 * Set global extra -> these will be sent with every event
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *_Nullable extraDictionary;

/**
 * used to add values in event context.
 */
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *_Nullable contextDictionary;

/**
 * Contains the breadcrumbs which will be sent with the event
 */
@property (nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;

/**
 * This distribution of the application.
 */
@property (atomic, copy) NSString *_Nullable distString;

/**
 * The environment used in this scope.
 */
@property (atomic, copy) NSString *_Nullable environmentString;

/**
 * Set the fingerprint of an event to determine the grouping
 */
@property (atomic, strong) NSArray<NSString *> *_Nullable fingerprintArray;

/**
 * SentryLevel of the event
 */
@property (atomic) enum SentryLevel levelEnum;

@property (atomic) NSInteger maxBreadcrumbs;

@property (atomic, strong) NSMutableArray<SentryAttachment *> *attachmentArray;

@end

@implementation SentryScope

#pragma mark Initializer

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
{
    if (self = [super init]) {
        self.listeners = [NSMutableArray new];
        self.maxBreadcrumbs = maxBreadcrumbs;
        [self clear];
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
        self.extraDictionary = scope.extraDictionary.mutableCopy;
        self.tagDictionary = scope.tagDictionary.mutableCopy;
        self.maxBreadcrumbs = scope.maxBreadcrumbs;
        self.userObject = scope.userObject.copy;
        self.contextDictionary = scope.contextDictionary.mutableCopy;
        self.breadcrumbArray = scope.breadcrumbArray.mutableCopy;
        self.distString = scope.distString;
        self.environmentString = scope.environmentString;
        self.levelEnum = scope.levelEnum;
        self.fingerprintArray = scope.fingerprintArray.mutableCopy;
        self.attachmentArray = scope.attachmentArray.mutableCopy;
    }
    return self;
}

#pragma mark Global properties

- (void)addBreadcrumb:(SentryBreadcrumb *)crumb
{
    [SentryLog logWithMessage:[NSString stringWithFormat:@"Add breadcrumb: %@", crumb]
                     andLevel:kSentryLogLevelDebug];
    @synchronized(self.breadcrumbArray) {
        [self.breadcrumbArray addObject:crumb];
        if ([self.breadcrumbArray count] > self.maxBreadcrumbs) {
            [self.breadcrumbArray removeObjectAtIndex:0];
        }
    }
    [self notifyListeners];
}

- (void)clear
{
    self.breadcrumbArray = [NSMutableArray new];
    self.userObject = nil;
    self.tagDictionary = [NSMutableDictionary new];
    self.extraDictionary = [NSMutableDictionary new];
    self.contextDictionary = [NSMutableDictionary new];
    self.distString = nil;
    self.environmentString = nil;
    self.levelEnum = kSentryLevelNone;
    self.fingerprintArray = [NSMutableArray new];
    self.attachmentArray = [NSMutableArray new];
    
    [self notifyListeners];
}

- (void)clearBreadcrumbs
{
    @synchronized(self.breadcrumbArray) {
        [self.breadcrumbArray removeAllObjects];
    }
    [self notifyListeners];
}

- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key
{
    @synchronized(self.contextDictionary) {
        [self.contextDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)removeContextForKey:(NSString *)key
{
    @synchronized(self.contextDictionary) {
        [self.contextDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setExtraValue:(id _Nullable)value forKey:(NSString *)key
{
    @synchronized(self.extraDictionary) {
        [self.extraDictionary setValue:value forKey:key];
    }
    [self notifyListeners];
}

- (void)removeExtraForKey:(NSString *)key
{
    @synchronized(self.extraDictionary) {
        [self.extraDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras
{
    if (extras == nil) {
        return;
    }
    @synchronized(self.extraDictionary) {
        [self.extraDictionary addEntriesFromDictionary:extras];
    }
    [self notifyListeners];
}

- (void)setTagValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(self.tagDictionary) {
        self.tagDictionary[key] = value;
    }
    [self notifyListeners];
}

- (void)removeTagForKey:(NSString *)key
{
    @synchronized(self.tagDictionary) {
        [self.tagDictionary removeObjectForKey:key];
    }
    [self notifyListeners];
}

- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags
{
    if (tags == nil) {
        return;
    }
    @synchronized(self.tagDictionary) {
        [self.tagDictionary addEntriesFromDictionary:tags];
    }
    [self notifyListeners];
}

- (void)setUser:(SentryUser *_Nullable)user
{
    self.userObject = user;
    [self notifyListeners];
}

- (void)setDist:(NSString *_Nullable)dist
{
    self.distString = dist;
    [self notifyListeners];
}

- (void)setEnvironment:(NSString *_Nullable)environment
{
    self.environmentString = environment;
    [self notifyListeners];
}

- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint
{
    @synchronized(self.fingerprintArray) {
        if (fingerprint == nil) {
            self.fingerprintArray = [NSMutableArray new];
        } else {
            self.fingerprintArray = fingerprint.mutableCopy;
        }
        self.fingerprintArray = fingerprint;
    }
    [self notifyListeners];
}

- (void)setLevel:(enum SentryLevel)level
{
    self.levelEnum = level;
    [self notifyListeners];
}

- (void)addAttachment:(SentryAttachment *)attachment
{
    @synchronized(self.attachmentArray) {
        [self.attachmentArray addObject:attachment];
    }
}

- (NSArray<SentryAttachment *> *)attachments
{
    @synchronized(self.attachmentArray) {
        return self.attachmentArray.copy;
    }
}

- (NSDictionary<NSString *, id> *)serialize
{
    NSMutableDictionary *serializedData = [NSMutableDictionary new];
    [serializedData setValue:[self.tagDictionary copy] forKey:@"tags"];
    [serializedData setValue:[self.extraDictionary copy] forKey:@"extra"];
    [serializedData setValue:[self.contextDictionary copy] forKey:@"context"];
    [serializedData setValue:[self.userObject serialize] forKey:@"user"];
    [serializedData setValue:self.distString forKey:@"dist"];
    [serializedData setValue:self.environmentString forKey:@"environment"];
    [serializedData setValue:[self.fingerprintArray copy] forKey:@"fingerprint"];
    if (self.levelEnum != kSentryLevelNone) {
        [serializedData setValue:SentryLevelNames[self.levelEnum] forKey:@"level"];
    }
    NSArray *crumbs = [self serializeBreadcrumbs];
    if (crumbs.count > 0) {
        [serializedData setValue:crumbs forKey:@"breadcrumbs"];
    }
    return serializedData;
}

- (NSArray *)serializeBreadcrumbs
{
    NSMutableArray *crumbs = [NSMutableArray new];

    @synchronized(self.breadcrumbArray) {
        for (SentryBreadcrumb *crumb in self.breadcrumbArray) {
            [crumbs addObject:[crumb serialize]];
        }
    }

    return crumbs;
}

- (void)applyToSession:(SentrySession *)session
{
    if (nil != self.userObject) {
        session.user = self.userObject.copy;
    }
    
    NSString *environment = self.environmentString;
    if (nil != environment) {
        // TODO: Make sure environment set on options is applied to the
        // scope so it's available now
        session.environment = environment;
    }
}

- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs
{
    if (nil != self.tagDictionary) {
        @synchronized(self.tagDictionary) {
            if (nil == event.tags) {
                event.tags = self.tagDictionary.copy;
            } else {
                NSMutableDictionary *newTags = [NSMutableDictionary new];
                [newTags addEntriesFromDictionary:self.tagDictionary];
                [newTags addEntriesFromDictionary:event.tags];
                event.tags = newTags;
            }
        }
    }

    if (nil != self.extraDictionary) {
        @synchronized(self.extraDictionary) {
            if (nil == event.extra) {
                event.extra = self.extraDictionary.copy;
            } else {
                NSMutableDictionary *newExtra = [NSMutableDictionary new];
                [newExtra addEntriesFromDictionary:self.extraDictionary];
                [newExtra addEntriesFromDictionary:event.extra];
                event.extra = newExtra;
            }
        }
    }
    
    @synchronized(self.fingerprintArray) {
        if (self.fingerprintArray.count > 0 && nil == event.fingerprint) {
            event.fingerprint = self.fingerprintArray.mutableCopy;
        }
    }
    
    @synchronized(self.breadcrumbArray) {
        if (nil == event.breadcrumbs) {
            event.breadcrumbs = [self.breadcrumbArray
                                 subarrayWithRange:NSMakeRange(0,
                                                               MIN(maxBreadcrumbs, [self.breadcrumbArray count]))];
        }
    }

    if (nil != self.contextDictionary) {
        @synchronized(self.contextDictionary) {
            if (nil == event.context) {
                event.context = self.contextDictionary;
            } else {
                NSMutableDictionary *newContext = [NSMutableDictionary new];
                [newContext addEntriesFromDictionary:self.contextDictionary];
                [newContext addEntriesFromDictionary:event.context];
                event.context = newContext;
            }
        }
    }
    
    if (nil != self.userObject) {
        event.user = self.userObject.copy;
    }
    
    NSString *dist = self.distString;
    if (nil != dist && nil == event.dist) {
        // dist can also be set via options but scope takes precedence.
        event.dist = dist;
    }
    
    NSString *environment = self.environmentString;
    if (nil != environment && nil == event.environment) {
        // environment can also be set via options but scope takes
        // precedence.
        event.environment = environment;
    }
    
    if (self.levelEnum != kSentryLevelNone) {
        // We always want to set the level from the scope since this has
        // benn set on purpose
        event.level = self.levelEnum;
    }
    
    return event;
}

@end

NS_ASSUME_NONNULL_END
