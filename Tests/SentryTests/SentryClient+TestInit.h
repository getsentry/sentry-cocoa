#import "SentryTransport.h"

@protocol SentryCurrentDateProvider;
@protocol SentryRandomProtocol;

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryDefaultThreadInspector;
@class SentryTransportAdapter;
@class SentryDebugImageProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient ()

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                             dateProvider:(id<SentryCurrentDateProvider>)dateProvider
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
                threadInspector:(SentryDefaultThreadInspector *)threadInspector
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone;

@end

NS_ASSUME_NONNULL_END
