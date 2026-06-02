#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCLevel.h"
#else
#    import <SentryObjC/SentryObjCLevel.h>
#endif

@class SentryObjCAttachment;
@class SentryObjCBreadcrumb;
@class SentryObjCSpan;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * The scope holds useful information that should be sent along with the event. For instance tags or
 * breadcrumbs are stored on the scope.
 * @see https://docs.sentry.io/platforms/apple/enriching-events/scopes/
 */
@interface SentryObjCScope : NSObject

/// The id of current session replay.
@property (nonatomic, copy, nullable) NSString *replayId;

/// Gets the dictionary of currently set tags.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;

/// Gets the dictionary of currently set attributes.
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *attributes;

- (instancetype)init;

/**
 * Initializes the scope with a maximum number of breadcrumbs.
 * @param maxBreadcrumbs The maximum number of breadcrumbs to store.
 */
- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs;

/// Set global user -> thus will be sent with every event.
- (void)setUser:(nullable SentryObjCUser *)user;

/// Set a global tag. Tags are searchable key/value string pairs attached to every event.
- (void)setTagValue:(NSString *)value forKey:(NSString *)key;

/// Remove the tag for the specified key.
- (void)removeTagForKey:(NSString *)key;

/// Set global tags. Tags are searchable key/value string pairs attached to every event.
- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags;

/// Set global extras -> these will be sent with every event.
- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras;

/// Set global extra -> these will be sent with every event.
- (void)setExtraValue:(nullable id)value forKey:(NSString *)key;

/// Remove the extra for the specified key.
- (void)removeExtraForKey:(NSString *)key;

/// Set @c dist in the scope.
- (void)setDist:(nullable NSString *)dist;

/// Set @c environment in the scope.
- (void)setEnvironment:(nullable NSString *)environment;

/// Sets the @c fingerprint in the scope.
- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint;

/// Sets the @c level in the scope.
- (void)setLevel:(SentryObjCLevel)level;

/// Add a breadcrumb to the scope.
- (void)addBreadcrumb:(SentryObjCBreadcrumb *)crumb;

/// Clears all breadcrumbs in the scope.
- (void)clearBreadcrumbs;

/**
 * Sets context values which will overwrite event context when the event is
 * enriched with the scope before sending.
 */
- (void)setContextValue:(NSDictionary<NSString *, id> *)value forKey:(NSString *)key;

/// Remove the context for the specified key.
- (void)removeContextForKey:(NSString *)key;

/**
 * Adds an attachment to the scope's list of attachments. The SDK adds the attachment to every event
 * sent to Sentry.
 * @param attachment The attachment to add to the scope's list of attachments.
 */
- (void)addAttachment:(SentryObjCAttachment *)attachment;

/**
 * Set global attributes. Attributes are searchable key/value string pairs attached to every log
 * message.
 * @note The SDK only applies attributes to Logs. The SDK doesn't apply the attributes to
 * Events, Transactions, Spans, Profiles, Session Replay.
 * @param value Supported values are string, integers, boolean, double and arrays of those types.
 * @param key The key to store, cannot be an empty string.
 */
- (void)setAttributeValue:(id)value forKey:(NSString *)key;

/**
 * Remove the attribute for the specified key.
 * @note The SDK only applies attributes to Logs. The SDK doesn't apply the attributes to
 * Events, Transactions, Spans, Profiles, Session Replay.
 */
- (void)removeAttributeForKey:(NSString *)key;

/// Clears all attachments in the scope.
- (void)clearAttachments;

/// The current Span or Transaction bound to the scope.
@property (nullable, nonatomic, strong) SentryObjCSpan *span;

/// Serializes the scope to a dictionary.
- (NSDictionary<NSString *, id> *)serialize;

/// Clears the current scope.
- (void)clear;

@end

NS_ASSUME_NONNULL_END
