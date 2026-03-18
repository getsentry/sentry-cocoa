#import <Foundation/Foundation.h>

#import "SentryObjCLevel.h"
#import "SentryObjCSerializable.h"
#import "SentryObjCSpanProtocol.h"

@class SentryAttachment;
@class SentryBreadcrumb;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Scope holds contextual data sent with every event (tags, breadcrumbs, user, etc.).
 *
 * The scope persists across captures and can be modified to add contextual
 * information to all subsequent events. Use @c +[SentrySDK configureScope:]
 * to access and modify the current scope.
 *
 * @see https://docs.sentry.io/platforms/apple/enriching-events/scopes/#whats-a-scope-whats-a-hub
 */
@interface SentryScope : NSObject <SentrySerializable>

/**
 * The currently active span or transaction.
 */
@property (nullable, nonatomic, strong) id<SentrySpan> span;

/**
 * ID of the current session replay.
 *
 * Set when a session replay is active.
 */
@property (nullable, nonatomic, strong) NSString *replayId;

/**
 * Currently set tags.
 *
 * Tags are key-value pairs that are indexed for search in Sentry.
 */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;

/**
 * Currently set attributes.
 *
 * Attributes provide additional metadata for spans and transactions.
 */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

/**
 * Creates a new scope with a maximum breadcrumb limit.
 *
 * @param maxBreadcrumbs Maximum number of breadcrumbs to retain.
 * @return A new scope instance.
 */
- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;

/**
 * Creates a new scope with default settings.
 *
 * @return A new scope instance.
 */
- (instancetype)init;

/**
 * Creates a new scope by copying another scope.
 *
 * @param scope The scope to copy from.
 * @return A new scope instance with copied data.
 */
- (instancetype)initWithScope:(SentryScope *)scope;

/**
 * Sets user information for this scope.
 *
 * @param user The user information to set.
 */
- (void)setUser:(SentryUser *)user;

/**
 * Sets a tag value for a specific key.
 *
 * @param value The tag value.
 * @param key The tag key.
 */
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;

/**
 * Removes a tag for the specified key.
 *
 * @param key The tag key to remove.
 */
- (void)removeTagForKey:(NSString *)key;

/**
 * Replaces all tags with the provided dictionary.
 *
 * @param tags Dictionary of tags to set.
 */
- (void)setTags:(NSDictionary<NSString *, NSString *> *)tags;

/**
 * Replaces all extras with the provided dictionary.
 *
 * @param extras Dictionary of extra data to set.
 */
- (void)setExtras:(NSDictionary<NSString *, id> *)extras;

/**
 * Sets an extra value for a specific key.
 *
 * @param value The extra value.
 * @param key The extra key.
 */
- (void)setExtraValue:(id)value forKey:(NSString *)key;

/**
 * Removes an extra value for the specified key.
 *
 * @param key The extra key to remove.
 */
- (void)removeExtraForKey:(NSString *)key;

/**
 * Sets the distribution identifier for this scope.
 *
 * @param dist The distribution identifier.
 */
- (void)setDist:(NSString *)dist;

/**
 * Sets the environment name for this scope.
 *
 * @param environment The environment name.
 */
- (void)setEnvironment:(NSString *)environment;

/**
 * Sets the fingerprint for grouping events.
 *
 * @param fingerprint Array of fingerprint strings.
 */
- (void)setFingerprint:(NSArray<NSString *> *)fingerprint;

/**
 * Sets the severity level for events from this scope.
 *
 * @param level The severity level.
 */
- (void)setLevel:(SentryLevel)level;

/**
 * Adds a breadcrumb to this scope.
 *
 * @param crumb The breadcrumb to add.
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb;

/**
 * Removes all breadcrumbs from this scope.
 */
- (void)clearBreadcrumbs;

/**
 * Serializes the scope to a dictionary.
 *
 * @return Dictionary representation of the scope.
 */
- (NSDictionary<NSString *, id> *)serialize;

/**
 * Sets a context value for a specific category.
 *
 * Common categories include "device", "os", "app", etc.
 *
 * @param value Dictionary of context data.
 * @param key The context category key.
 */
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;

/**
 * Removes context for the specified category.
 *
 * @param key The context category key to remove.
 */
- (void)removeContextForKey:(NSString *)key;

/**
 * Adds an attachment to this scope.
 *
 * Attachments are sent with all subsequent events from this scope.
 *
 * @param attachment The attachment to add.
 */
- (void)addAttachment:(SentryAttachment *)attachment;

/**
 * Sets an attribute value for a specific key.
 *
 * @param value The attribute value.
 * @param key The attribute key.
 */
- (void)setAttributeValue:(id)value forKey:(NSString *)key;

/**
 * Removes an attribute for the specified key.
 *
 * @param key The attribute key to remove.
 */
- (void)removeAttributeForKey:(NSString *)key;

/**
 * Removes all attachments from this scope.
 */
- (void)clearAttachments;

/**
 * Clears all data from this scope.
 *
 * Resets user, tags, extras, context, breadcrumbs, and attachments.
 */
- (void)clear;

@end

NS_ASSUME_NONNULL_END
