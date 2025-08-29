#import "SentryTransport.h"

@protocol SentryRandomProtocol;

@class SentryCrashWrapper;
@class SentryDispatchQueueWrapper;
@class SentryThreadInspector;
@class SentryTransportAdapter;
@class SentryDebugImageProvider;

NS_ASSUME_NONNULL_BEGIN

@interface SentryClient ()

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
             debugImageProvider:(SentryDebugImageProvider *)debugImageProvider
                         random:(id<SentryRandomProtocol>)random
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone;

@end

NS_ASSUME_NONNULL_END
