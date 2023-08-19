#import "SentryRandom.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashWrapper, SentryThreadInspector, SentryTransportAdapter, SentryUIDeviceWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                            dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                   deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems;

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                              fileManager:(SentryFileManager *)fileManager
                   deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems;

- (instancetype)initWithOptions:(SentryOptions *)options
                    fileManager:(SentryFileManager *)fileManager
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
               transportAdapter:(SentryTransportAdapter *)transportAdapter;

- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone;

@end

NS_ASSUME_NONNULL_END
