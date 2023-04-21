#import "SentryExtraContextProvider.h"
#import "SentryRandom.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashWrapper, SentryThreadInspector, SentryTransportAdapter, SentryUIDeviceWrapper,
    SentryCrashWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                            dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                             crashWrapper:(SentryCrashWrapper *)crashWrapper
                   deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems;

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                              fileManager:(SentryFileManager *)fileManager
                             crashWrapper:(SentryCrashWrapper *)crashWrapper
                   deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems;

- (instancetype)initWithOptions:(SentryOptions *)options
                    fileManager:(SentryFileManager *)fileManager
                   crashWrapper:(SentryCrashWrapper *)crashWrapper
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
               transportAdapter:(SentryTransportAdapter *)transportAdapter;

- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                   crashWrapper:(SentryCrashWrapper *)crashWrapper
         deleteOldEnvelopeItems:(BOOL)deleteOldEnvelopeItems
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone
           extraContextProvider:(SentryExtraContextProvider *)extraContextProvider;

@end

NS_ASSUME_NONNULL_END
