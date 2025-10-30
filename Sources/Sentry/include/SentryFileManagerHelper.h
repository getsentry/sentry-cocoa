#import "SentryDefines.h"
#import "SentryProfilingConditionals.h"

NS_ASSUME_NONNULL_BEGIN

@class SentryAppState;
@class SentryDispatchQueueWrapper;
@class SentryEvent;
@class SentryEnvelope;
@class SentryEnvelopeItem;
@class SentryOptions;
@class SentrySession;

@protocol SentryCurrentDateProvider;

@interface SentryFileManagerHelper : NSObject
SENTRY_NO_INIT

@property (nonatomic, readonly) NSString *basePath;
@property (nonatomic, readonly) NSString *sentryPath;

@property (nonatomic, readonly) NSString *breadcrumbsFilePathOne;
@property (nonatomic, readonly) NSString *breadcrumbsFilePathTwo;
@property (nonatomic, readonly) NSString *previousBreadcrumbsFilePathOne;
@property (nonatomic, readonly) NSString *previousBreadcrumbsFilePathTwo;

@property (nonatomic, copy) NSString *envelopesPath;
@property (nonatomic, assign) NSUInteger maxEnvelopes;
@property (nonatomic, copy) NSString *timezoneOffsetFilePath;
@property (nonatomic, copy) NSString *eventsPath;
@property (nonatomic, copy) NSString *appStateFilePath;
@property (nonatomic, copy) NSString *appHangEventFilePath;

@property (nonatomic, copy, nullable) void (^handleEnvelopesLimit)(void);

- (nullable instancetype)initWithOptions:(SentryOptions *_Nullable)options
                                   error:(NSError **)error NS_DESIGNATED_INITIALIZER;

#pragma mark - Envelope

- (nullable NSString *)storeEnvelopeData:(NSData *)envelopeData
                             currentTime:(NSTimeInterval)currentTime;
/**
 * Only used for testing.
 */
- (nullable NSString *)getEnvelopesPath:(NSString *)filePath;

- (NSArray<NSString *> *_Nullable)pathsOfAllEnvelopes;

- (void)deleteOldEnvelopesFromAllSentryPaths:(NSTimeInterval)now;

/**
 * Only used for teting.
 */
- (void)deleteAllEnvelopes;

#pragma mark - Convenience Accessors
- (NSURL *)getSentryPathAsURL;

#pragma mark - State
- (void)moveState:(NSString *)stateFilePath toPreviousState:(NSString *)previousStateFilePath;

#pragma mark - Session
- (void)storeCurrentSessionData:(nullable NSData *)data;
- (NSData *_Nullable)readCurrentSession;
- (void)deleteCurrentSession;

- (void)storeCrashedSessionData:(nullable NSData *)data;
- (NSData *_Nullable)readCrashedSession;
- (void)deleteCrashedSession;

- (void)storeAbnormalSessionData:(nullable NSData *)data;
- (NSData *_Nullable)readAbnormalSession;
- (void)deleteAbnormalSession;

#pragma mark - LastInForeground
- (void)storeTimestampLastInForeground:(NSDate *)timestamp;
- (NSDate *_Nullable)readTimestampLastInForeground;
- (void)deleteTimestampLastInForeground;

#pragma mark - App State
- (void)storeAppStateData:(NSData *)appState;
- (void)moveAppStateToPreviousAppState;
- (NSData *_Nullable)readAppStateData;
- (NSData *_Nullable)readPreviousAppState;
- (void)deleteAppState;

#pragma mark - Breadcrumbs
- (void)moveBreadcrumbsToPreviousBreadcrumbs;
- (NSArray *)readPreviousBreadcrumbs;

#pragma mark - TimezoneOffset
- (NSNumber *_Nullable)readTimezoneOffset;
- (void)storeTimezoneOffset:(NSInteger)offset;
- (void)deleteTimezoneOffset;

#pragma mark - AppHangs
- (void)storeAppHangEvent:(SentryEvent *)appHangEvent;
- (nullable SentryEvent *)readAppHangEvent;
- (BOOL)appHangEventExists;
- (void)deleteAppHangEvent;

#pragma mark - File Operations
+ (BOOL)createDirectoryAtPath:(NSString *)path withError:(NSError **)error;
- (void)deleteAllFolders;
- (void)removeFileAtPath:(NSString *)path;
- (NSArray<NSString *> *)allFilesInFolder:(NSString *)path;
- (BOOL)isDirectory:(NSString *)path;
- (nullable NSData *)readDataFromPath:(NSString *)path
                                error:(NSError *__autoreleasing _Nullable *)error;
- (BOOL)writeData:(nullable NSData *)data toPath:(NSString *)path;

BOOL createDirectoryIfNotExists(NSString *path, NSError **error);

/**
 * Path for a default directory Sentry can use in the app sandbox' caches directory.
 * @note This method must be statically accessible because it will be called during app launch,
 * before any instance of @c SentryFileManager exists, and so wouldn't be able to access this path.
 * @note For unsandboxed macOS apps, the path has the form @c ~/Library/Caches/<app-bundle-id> .
 * from an objc property on it like the other paths. It also cannot use
 * @c SentryOptions.cacheDirectoryPath since this can be called before
 * @c SentrySDK.startWithOptions .
 */
SENTRY_EXTERN NSString *_Nullable sentryStaticCachesPath(void);

#pragma mark - Profiling

#if SENTRY_TARGET_PROFILING_SUPPORTED
/**
 * @return @c YES if a launch profile config file is present, @c NO otherwise. If a config file is
 * present, this means that a sample decision of @c YES was computed using the resolved traces and
 * profiles sample rates provided in the previous launch's call to @c SentrySDK.startWithOptions .
 * @note This is implemented as a C function instead of an Objective-C method in the interest of
 * fast execution at launch time.
 */
SENTRY_EXTERN BOOL appLaunchProfileConfigFileExists(void);

/**
 * Retrieve the contents of the launch profile config file, which stores the sample rates used to
 * decide whether or not to profile this launch.
 */
SENTRY_EXTERN NSDictionary<NSString *, NSNumber *>
    *_Nullable sentry_persistedLaunchProfileConfigurationOptions(void);

/**
 * Write a config file that stores the sample rates used to determine whether this launch should
 * have been profiled.
 */
SENTRY_EXTERN void writeAppLaunchProfilingConfigFile(
    NSMutableDictionary<NSString *, NSNumber *> *config);

/**
 * Remove an existing launch profile config file. If this launch was profiled, then a config file is
 * present, and if the following call to @c SentrySDK.startWithOptions determines the next launch
 * should not be profiled, then we must remove the config file, or the next launch would see it and
 * start the profiler.
 */
SENTRY_EXTERN void removeAppLaunchProfilingConfigFile(void);

SENTRY_EXTERN NSString *_Nullable sentryStaticBasePath(void);

#    if defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)
SENTRY_EXTERN void removeSentryStaticBasePath(void);
#    endif // defined(SENTRY_TEST) || defined(SENTRY_TEST_CI) || defined(DEBUG)

#endif // SENTRY_TARGET_PROFILING_SUPPORTED

- (void)clearDiskState;

@end

NS_ASSUME_NONNULL_END
