#if __has_include(<Sentry/Sentry.h>)
#    import <Sentry/SentryDefines.h>
#elif __has_include(<SentryWithoutUIKit/Sentry.h>)
#    import <SentryWithoutUIKit/SentryDefines.h>
#else
#    import <SentryDefines.h>
#endif
#if !SDK_V9
#    import SENTRY_HEADER(SentrySerializable)
#endif // SDK_V9
#import SENTRY_HEADER(SentrySpanProtocol)

@class SentryAttachment;
@class SentryBreadcrumb;
@class SentryOptions;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * The scope holds useful information that should be sent along with the event. For instance tags or
 * breadcrumbs are stored on the scope.
 * @see
 * https://docs.sentry.io/platforms/apple/enriching-events/scopes/#whats-a-scope-whats-a-hub
 */
NS_SWIFT_NAME(Scope)
@interface SentryScope : NSObject
#if !SDK_V9
                         <SentrySerializable>
#endif // !SDK_V9

/**
 * Returns current Span or Transaction.
 * @return current Span or Transaction or null if transaction has not been set.
 */
@property (nullable, nonatomic, strong) id<SentrySpan> span;

/**
 * The id of current session replay.
 */
@property (nullable, nonatomic, strong) NSString *replayId;

/**
 * Gets the dictionary of currently set tags.
 */
@property (nonatomic, readonly, copy) NSDictionary<NSString *, NSString *> *tags;

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
 * Set @c dist in the scope
 */
- (void)setDist:(NSString *_Nullable)dist;

/**
 * Set @c environment in the scope
 */
- (void)setEnvironment:(NSString *_Nullable)environment;

/**
 * Sets the @c fingerprint in the scope
 */
- (void)setFingerprint:(NSArray<NSString *> *_Nullable)fingerprint;

/**
 * Sets the @c level in the scope
 */
- (void)setLevel:(enum SentryLevel)level;

/**
 * Add a breadcrumb to the scope
 */
- (void)addBreadcrumb:(SentryBreadcrumb *)crumb NS_SWIFT_NAME(addBreadcrumb(_:));

- (void)add:(SentryBreadcrumb *)crumb DEPRECATED_MSG_ATTRIBUTE("use `addBreadcrumb` instead")
                NS_SWIFT_NAME(add(_:));

/**
 * Clears all breadcrumbs in the scope
 */
- (void)clearBreadcrumbs;

#if !SDK_V9
/**
 * Serializes the Scope to JSON
 */
- (NSDictionary<NSString *, id> *)serialize;
#endif // !SDK_V9

/**
 * Sets context values which will overwrite SentryEvent.context when event is
 * "enriched" with scope before sending event.
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
 * @param attachment The attachment to add to the Scope's list of attachments.
 */
- (void)addAttachment:(SentryAttachment *)attachment NS_SWIFT_NAME(addAttachment(_:));

// We want to keep the old Swift `add(_ attachment:)` function as deprecated, but we cant have
// another objc `add` method
- (void)includeAttachment:(SentryAttachment *)attachment
    DEPRECATED_MSG_ATTRIBUTE("use `addAttachment` instead")NS_SWIFT_NAME(add(_:));

/**
 * Clears all attachments in the scope.
 */
- (void)clearAttachments;

/**
 * Clears the current Scope
 */
- (void)clear;

#if !SDK_V9
/**
 * Mutates the current transaction atomically.
 * @param callback the SentrySpanCallback.
 */
- (void)useSpan:(SentrySpanCallback)callback
    DEPRECATED_MSG_ATTRIBUTE(
        "This method was used to create an atomic block that could be used to mutate the current "
        "span. It is not atomic anymore and due to issues with memory safety in `NSBlock` it is "
        "now considered unsafe and deprecated. Use `span` instead.");
#endif // !SDK_V9

/**
 * Returns the current span.
 */
- (id<SentrySpan> _Nullable)span;

@end

NS_ASSUME_NONNULL_END
