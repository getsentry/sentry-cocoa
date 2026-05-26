#import <Foundation/Foundation.h>
#import <SentryObjC/SentryObjCLevel.h>

@class SentryObjCBreadcrumb;
@class SentryObjCDebugMeta;
@class SentryObjCException;
@class SentryObjCId;
@class SentryObjCMessage;
@class SentryObjCRequest;
@class SentryObjCStacktrace;
@class SentryObjCThread;
@class SentryObjCUser;

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents a Sentry event that is sent to the server.
 */
@interface SentryObjCEvent : NSObject

/// This will be set by the initializer.
@property (nonatomic, strong) SentryObjCId *eventId;

/// Message of the event.
@property (nonatomic, strong, nullable) SentryObjCMessage *message;

/**
 * The error of the event. This property adds convenience to access the error directly in
 * @c beforeSend. This property is not serialized. Instead when preparing the event the
 * client puts the error and any underlying errors into exceptions.
 */
@property (nonatomic, copy, nullable) NSError *error;

/// @c NSDate of when the event occurred.
@property (nonatomic, strong, nullable) NSDate *timestamp;

/// @c NSDate of when the event started, mostly useful if event type is transaction.
@property (nonatomic, strong, nullable) NSDate *startTimestamp;

/// @c SentryObjCLevel of the event.
@property (nonatomic) SentryObjCLevel level;

/// This will be used for symbolicating on the server, should be "cocoa".
@property (nonatomic, copy) NSString *platform;

/// Define the logger name.
@property (nonatomic, copy, nullable) NSString *logger;

/// Define the server name.
@property (nonatomic, copy, nullable) NSString *serverName;

/**
 * @note This property will be filled before the event is sent.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, copy, nullable) NSString *releaseName;

/**
 * @note This property will be filled before the event is sent.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, copy, nullable) NSString *dist;

/// The environment used for this event.
@property (nonatomic, copy, nullable) NSString *environment;

/// The name of the transaction which caused this event.
@property (nonatomic, copy, nullable) NSString *transaction;

/// The type of the event, null, default or transaction.
@property (nonatomic, copy, nullable) NSString *type;

/// Arbitrary key:value (string:string) data that will be shown with the event.
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *tags;

/// Arbitrary additional information that will be sent with the event.
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *extra;

/**
 * Information about the SDK.
 * @warning This is automatically maintained and should not normally need to be modified.
 */
@property (nonatomic, strong, nullable) NSDictionary<NSString *, id> *sdk;

/// Modules of the event.
@property (nonatomic, strong, nullable) NSDictionary<NSString *, NSString *> *modules;

/// Set the fingerprint of an event to determine the grouping.
@property (nonatomic, strong, nullable) NSArray<NSString *> *fingerprint;

/// Set the user for the event.
@property (nonatomic, strong, nullable) SentryObjCUser *user;

/**
 * This object contains meta information.
 * @warning This is maintained automatically, and shouldn't normally need to be modified.
 */
@property (nonatomic, strong, nullable)
    NSDictionary<NSString *, NSDictionary<NSString *, id> *> *context;

/// Contains thread information if a crash occurred or for a user reported exception.
@property (nonatomic, strong, nullable) NSArray<SentryObjCThread *> *threads;

/**
 * General information about the exception. Multiple exceptions indicate a chain of
 * exceptions encountered, starting with the oldest at the beginning of the array.
 */
@property (nonatomic, strong, nullable) NSArray<SentryObjCException *> *exceptions;

/// Separate stacktrace that can be sent with the event, besides threads.
@property (nonatomic, strong, nullable) SentryObjCStacktrace *stacktrace;

/// Containing images loaded during runtime.
@property (nonatomic, strong, nullable) NSArray<SentryObjCDebugMeta *> *debugMeta;

/// This contains all breadcrumbs available at the time when the event occurred/will be sent.
@property (nonatomic, strong, nullable) NSArray<SentryObjCBreadcrumb *> *breadcrumbs;

/// Set the HTTP request information.
@property (nonatomic, strong, nullable) SentryObjCRequest *request;

/// Init an @c SentryObjCEvent will set all needed fields by default.
- (instancetype)init;

/// Init a @c SentryObjCEvent with the given level and set all needed fields by default.
- (instancetype)initWithLevel:(SentryObjCLevel)level;

/**
 * Initializes a @c SentryObjCEvent with an @c NSError and sets the level to error.
 * @param error The error of the event.
 */
- (instancetype)initWithError:(NSError *)error;

@end

NS_ASSUME_NONNULL_END
