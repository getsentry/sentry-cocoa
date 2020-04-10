#import <Foundation/Foundation.h>

#import "SentryDefines.h"
#import "SentrySession.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryEvent, SentryDsn, SentryEnvelope;

NS_SWIFT_NAME(SentryFileManager)
@interface SentryFileManager : NSObject
SENTRY_NO_INIT

- (_Nullable instancetype)initWithDsn:(SentryDsn *)dsn didFailWithError:(NSError **)error NS_DESIGNATED_INITIALIZER;

- (NSString *)storeEvent:(SentryEvent *)event;
- (NSString *)storeEnvelope:(SentryEnvelope *)envelope;

- (void)storeCurrentSession:(SentrySession *)session;
- (SentrySession *_Nullable)readCurrentSession;
- (void)deleteCurrentSession;

+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;

- (void)deleteAllStoredEvents;

- (void)deleteAllFolders;

- (NSArray<NSDictionary<NSString *, id> *> *)getAllStoredEvents;

- (BOOL)removeFileAtPath:(NSString *)path;

- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;

- (NSString *)storeDictionary:(NSDictionary *)dictionary toPath:(NSString *)path;

@property(nonatomic, assign) NSUInteger maxEvents;

@end

NS_ASSUME_NONNULL_END
