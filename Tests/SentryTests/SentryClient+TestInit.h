#import "SentryRandom.h"
#import "SentryTransport.h"
#import <Sentry/Sentry.h>

@class SentryCrashWrapper, SentryThreadInspector, SentryTransportAdapter, SentryUIDeviceWrapper;

NS_ASSUME_NONNULL_BEGIN

@interface
SentryClient ()

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                            dispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue;

- (_Nullable instancetype)initWithOptions:(SentryOptions *)options
                              fileManager:(SentryFileManager *)fileManager;

- (instancetype)initWithOptions:(SentryOptions *)options
                    fileManager:(SentryFileManager *)fileManager
               transportAdapter:(SentryTransportAdapter *)transportAdapter;

- (instancetype)initWithOptions:(SentryOptions *)options
               transportAdapter:(SentryTransportAdapter *)transportAdapter
                    fileManager:(SentryFileManager *)fileManager
                threadInspector:(SentryThreadInspector *)threadInspector
                         random:(id<SentryRandom>)random
                   crashWrapper:(SentryCrashWrapper *)crashWrapper
                  deviceWrapper:(SentryUIDeviceWrapper *)deviceWrapper
                         locale:(NSLocale *)locale
                       timezone:(NSTimeZone *)timezone;

@end

NS_ASSUME_NONNULL_END
