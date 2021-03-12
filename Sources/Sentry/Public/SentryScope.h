#import "SentryDefines.h"
#import "SentrySerializable.h"
#import "SentrySpanProtocol.h"

@class SentryUser, SentrySession, SentryOptions, SentryBreadcrumb, SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject <SentrySerializable>

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (instancetype)initWithScope:(SentryScope *)scope;

/**
 * Set global user -> thus will be sent with every event
 */
- (void)setUser:(SentryUser *_Nullable)user;

/**
 * Set a global tag. Tags are searchable key/value string pairs attached to
 * every event.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key NS_SWIFT_NAME(setTag(value:key:));

/**
 * Remove the tag for the specified key.
 */
- (void)removeTagForKey:(NSString *)key NS_SWIFT_NAME(removeTag(key:));

/**
 * Set global tags. Tags are searchable key/value string pairs attached to every
 * event.
 */
- (void)setTags:(NSDictionary<NSString *, NSString *> *_Nullable)tags;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtras:(NSDictionary<NSString *, id> *_Nullable)extras;

/**
 * Set global extra -> these will be sent with every event
 */
- (void)setExtraValue:(id _Nullable)value
               forKey:(NSString *)key NS_SWIFT_NAME(setExtra(value:key:));

/**
 * Remove the extra for the specified key.
 */
- (void)removeExtraForKey:(NSString *)key NS_SWIFT_NAME(removeExtra(key:));

/**
 * Set dist in the scope
 */
- (void)setDist:(NSString *_Nullable)dist;

/**
 * Set environment in the scope
 */
- (void)setEnvironment:(NSString *_Nullable)environment;

/**
 * Sets the fingerprint in the scope
 */
- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint;

/**
 * Sets the level in the scope
 */
- (void)setLevel:(enum SentryLevel)level;

/**
 * Add a breadcrumb to the scope
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Clears all breadcrumbs in the scope
 */
- (void)clearBreadcrumbs;

/**
 * Serializes the Scope to JSON
 */
- (NSDictionary<NSString *, id> *)serialize;

/**
 * Adds the Scope to the event
 */
- (SentryEvent *__nullable)applyToEvent:(SentryEvent *)event
                          maxBreadcrumb:(NSUInteger)maxBreadcrumbs;

- (void)applyToSession:(SentrySession *)session;

/**
 * Sets context values which will overwrite SentryEvent.context when event is
 * "enrichted" with scope before sending event.
 */
- (void)setContextValue:(NSDictionary<NSString *, id> *)value
                 forKey:(NSString *)key NS_SWIFT_NAME(setContext(value:key:));

/**
 * Remove the context for the specified key.
 */
- (void)removeContextForKey:(NSString *)key NS_SWIFT_NAME(removeContext(key:));

/**
 * Adds an attachment to the Scope's list of attachments. The SDK adds the attachment to every event
 * sent to Sentry.
 *
 * @param attachment The attachment to add to the Scope's list of attachments.
 */
- (void)addAttachment:(SentryAttachment *)attachment;

/**
 * Add a transaction to the Scope with given key.
 * This key can be used to retrieve the transaction in a later moment.
 * If a transaction with the same key exists the previous added transaction will be lost.
 *
 * @param transaction A transaction to add to the Scope.
 * @param key A key to identify the transaction
 */
- (void)setTransaction:(id<SentrySpan>)transaction
                forKey:(NSString *)key NS_SWIFT_NAME(addTransaction(transaction:key:));

/**
 * Retrieve a previous added transaction with given key.
 *
 * @param key A key used to previously store a transaction.
 *
 * @return A previous added transaction with given key or nil.
 */
- (nullable id<SentrySpan>)getTransactionForKey:(NSString *)key NS_SWIFT_NAME(getTransaction(key:));

/**
 * Finish a transaction with given key and remove it from the scope.
 *
 * @param key A key used to previously store a transaction.
 */
- (void)finishTransactionForKey:(NSString *)key NS_SWIFT_NAME(finishTransaction(key:));
;

/**
 * Removes a transaction from the scope.
 *
 * @param key A key used to previously store a transaction.
 */
- (void)removeTransactionForKey:(NSString *)key NS_SWIFT_NAME(removeTransaction(key:));
;

/**
 * Removes a transaction from the scope.
 */
- (void)removeTransaction:(id<SentrySpan>)transaction;

/**
 * Clears the current Scope
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
