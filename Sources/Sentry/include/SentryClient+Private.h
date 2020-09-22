#import "SentryClient.h"
#import <Foundation/Foundation.h>

@class SentryId;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient (Private)

- (SentryId *)captureError:(NSError *)error
               withSession:(SentrySession *)session
                 withScope:(SentryScope *_Nullable)scope;

- (SentryId *)captureException:(NSException *)exception
                   withSession:(SentrySession *)session
                     withScope:(SentryScope *_Nullable)scope;

- (SentryId *)captureEvent:(SentryEvent *)event
               withSession:(SentrySession *)session
                 withScope:(SentryScope *_Nullable)scope;

@end

NS_ASSUME_NONNULL_END
