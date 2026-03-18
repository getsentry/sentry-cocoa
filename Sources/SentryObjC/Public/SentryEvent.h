#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryLevel.h"
#import "SentrySerializable.h"

@class SentryBreadcrumb;
@class SentryDebugMeta;
@class SentryException;
@class SentryId;
@class SentryMessage;
@class SentryRequest;
@class SentryStacktrace;
@class SentryThread;
@class SentryUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Event payload sent to Sentry.
 *
 * Represents an error, exception, or message that will be sent to Sentry.
 * Events can be enriched with context from the scope before being sent.
 *
 * @see SentrySDK
 * @see SentryClient
 */
@interface SentryEvent : NSObject <SentrySerializable>

/**
 * Unique identifier for this event.
 *
 * Automatically generated when the event is created.
 */
@property (nonatomic, strong) SentryId *eventId;

/**
 * Message associated with this event.
 *
 * Used for message events to provide a formatted message.
 */
@property (nonatomic, strong, nullable) SentryMessage *message;

/**
 * The @c NSError associated with this event.
 *
 * This property provides convenience access to the error in @c beforeSend.
 * It is not directly serialized; errors are converted to exceptions.
 */
@property (nonatomic, copy, nullable) NSError *error;

/**
 * Timestamp when the event occurred.
 *
 * If not set, defaults to the current time when the event is captured.
 */
@property (nonatomic, strong, nullable) NSDate *timestamp;

/**
 * Timestamp when the event started.
 *
 * Primarily used for transaction events to indicate when the transaction began.
 */
@property (nonatomic, strong, nullable) NSDate *startTimestamp;

/**
 * Severity level of the event.
 *
 * Defaults to @c kSentryLevelError.
 */
@property (nonatomic) SentryLevel level;

/**
 * Platform identifier for symbolication.
 *
 * Always set to "cocoa" for iOS/macOS events.
 */
@property (nonatomic, copy) NSString *platform;

/**
 * Name of the logger that captured this event.
 */
@property (nonatomic, copy, nullable) NSString *logger;

/**
 * Server or device name where the event occurred.
 */
@property (nonatomic, copy, nullable) NSString *serverName;

/**
 * Release version identifier.
 *
 * @note Filled automatically before the event is sent.
 * @warning Usually managed automatically; manual changes not recommended.
 */
@property (nonatomic, copy, nullable) NSString *releaseName;

/**
 * Distribution identifier for this release.
 *
 * @note Filled automatically before the event is sent.
 * @warning Usually managed automatically; manual changes not recommended.
 */
@property (nonatomic, copy, nullable) NSString *dist;

/**
 * Environment name where the event occurred.
 */
@property (nonatomic, copy, nullable) NSString *environment;

/**
 * Name of the transaction associated with this event.
 */
@property (nonatomic, copy, nullable) NSString *transaction;

/**
 * Type of event.
 *
 * Can be "default", "transaction", or @c nil.
 */
@property (nonatomic, copy, nullable) NSString *type;

/**
 * Key-value tags for categorizing and filtering events.
 *
 * Tags are searchable in the Sentry UI.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *tags;

/**
 * Arbitrary extra data associated with the event.
 *
 * This data is displayed in the Sentry UI but is not indexed for search.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *extra;

/**
 * SDK metadata.
 *
 * @warning Usually managed automatically; manual changes not recommended.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *sdk;

/**
 * List of loaded modules (frameworks/libraries) and their versions.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *modules;

/**
 * Fingerprint for grouping events.
 *
 * Events with the same fingerprint are grouped into the same issue.
 * If not set, Sentry uses default grouping algorithms.
 */
@property (nonatomic, strong, nullable) NSArray<NSString *> *fingerprint;

/**
 * User information associated with this event.
 */
@property (nonatomic, strong, nullable) SentryUser *user;

/**
 * Additional context data organized by category.
 *
 * Common categories include "device", "os", "app", "browser", etc.
 */
@property (nonatomic, strong, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;

/**
 * List of threads running when the event occurred.
 *
 * Typically populated for crash events.
 */
@property (nonatomic, strong, nullable) NSArray<SentryThread *> *threads;

/**
 * List of exceptions associated with this event.
 *
 * Can contain multiple exceptions for chained or nested errors.
 */
@property (nonatomic, strong, nullable) NSArray<SentryException *> *exceptions;

/**
 * Stack trace for this event.
 *
 * Used when the event represents a single error or exception.
 */
@property (nonatomic, strong, nullable) SentryStacktrace *stacktrace;

/**
 * Debug metadata for symbolication.
 *
 * Contains information about debug images (binaries) loaded at crash time.
 */
@property (nonatomic, strong, nullable) NSArray<SentryDebugMeta *> *debugMeta;

/**
 * Breadcrumbs that provide context leading up to the event.
 *
 * Breadcrumbs are a trail of events that occurred before this event.
 */
@property (nonatomic, strong, nullable) NSArray<SentryBreadcrumb *> *breadcrumbs;

/**
 * HTTP request information associated with this event.
 */
@property (nonatomic, strong, nullable) SentryRequest *request;

/**
 * Creates a new event with default values.
 *
 * @return A new event instance.
 */
- (instancetype)init;

/**
 * Creates a new event with the specified severity level.
 *
 * @param level The severity level for this event.
 * @return A new event instance.
 */
- (instancetype)initWithLevel:(SentryLevel)level;

/**
 * Creates a new event from an @c NSError.
 *
 * @param error The error to create an event from.
 * @return A new event instance.
 */
- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
