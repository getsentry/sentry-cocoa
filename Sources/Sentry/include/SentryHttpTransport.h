#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentryScope.h"
#import "SentryEvent.h"
#import "SentryEnvelope.h"
#import "SentryTransport.h"
#import "SentryRequestManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryHttpTransport : NSObject <SentryTransport>
SENTRY_NO_INIT


- (id)initWithOptions:(SentryOptions *)options
    sentryFileManager:(SentryFileManager *)sentryFileManager
 sentryRequestManager:(id<SentryRequestManager>) sentryRequestManager;

/**
 * This is triggered after the first upload attempt of an event. Checks if event
 * should stay on disk to be uploaded when `sendAllStoredEvents` is triggerd.
 *
 * Within `sendAllStoredEvents` this function isn't triggerd.
 *
 * @return BOOL YES = store and try again later, NO = delete
 */
@property(nonatomic, copy) SentryShouldQueueEvent _Nullable shouldQueueEvent;

/**
 * Contains the last successfully sent event
 */
@property(nonatomic, strong) SentryEvent *_Nullable lastEvent;

@end

NS_ASSUME_NONNULL_END
