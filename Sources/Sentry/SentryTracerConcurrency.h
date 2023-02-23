#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

typedef void (^SentryConcurrentTransactionCleanupBlock)(void);

/** Track the tracer with specified ID to help with operations that need to know about all in-flight
 * concurrent tracers. */
void trackTracerWithID(SentryId *traceID);

/**
 * Stop tracking the tracer with the specified ID, and if it was the last concurrent tracer in
 * flight, perform the cleanup actions.
 */
void stopTrackingTracerWithID(SentryId *traceID, SentryConcurrentTransactionCleanupBlock cleanup);

NS_ASSUME_NONNULL_END
