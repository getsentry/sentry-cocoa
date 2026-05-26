#import <Foundation/Foundation.h>

@class SentryObjCId;
@class SentryObjCTraceContext;

NS_ASSUME_NONNULL_BEGIN

/**
 * The header of a @c SentryObjCEnvelope, containing metadata about the envelope
 * such as the event identifier and trace context.
 */
@interface SentryObjCEnvelopeHeader : NSObject

/**
 * The event identifier, if available.
 * An event ID exists if the envelope contains an event or items within it are related,
 * e.g. attachments.
 */
@property (nonatomic, readonly, strong, nullable) SentryObjCId *eventId;

/// Current trace state.
@property (nonatomic, readonly, strong, nullable) SentryObjCTraceContext *traceContext;

/**
 * The timestamp when the event was sent from the SDK. Used for clock drift correction of the
 * event timestamp. The time zone must be UTC.
 *
 * The timestamp should be generated as close as possible to the transmission of the event,
 * so that the delay between sending the envelope and receiving it on the server-side is minimized.
 */
@property (nonatomic, strong, nullable) NSDate *sentAt;

/**
 * Initializes an envelope header with the specified event ID.
 * @note Sets the @c sdkInfo from @c SentryMeta.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
 * attachment related to event.
 */
- (instancetype)initWithId:(nullable SentryObjCId *)eventId;

/**
 * Initializes an envelope header with the specified event ID and trace context.
 * @param eventId The identifier of the event. Can be @c nil if no event in the envelope or
 * attachment related to event.
 * @param traceContext Current trace state.
 */
- (instancetype)initWithId:(nullable SentryObjCId *)eventId
              traceContext:(nullable SentryObjCTraceContext *)traceContext;

/// Creates an empty envelope header with no event ID or trace context.
+ (instancetype)empty;

@end

NS_ASSUME_NONNULL_END
