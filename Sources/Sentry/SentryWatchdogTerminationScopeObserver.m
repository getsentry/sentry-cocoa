#import "SentryWatchdogTerminationScopeObserver.h"

#if SENTRY_HAS_UIKIT

#    import <SentryBreadcrumb.h>
#    import <SentryFileManager.h>
#    import <SentryLog.h>

@interface SentryWatchdogTerminationScopeObserver ()

@property (strong, nonatomic) SentryFileManager *fileManager;

@property (strong, nonatomic) NSFileHandle *fileHandleBreadcrumbs;
@property (strong, nonatomic) NSString *activeFilePathBreadcrumbs;
@property (nonatomic) NSInteger maxBreadcrumbs;
@property (nonatomic) NSInteger breadcrumbCounter;

@property (nonatomic, strong) NSFileHandle *fileHandleContext;
@property (strong, nonatomic) NSString *activeFilePathContext;

@end

@implementation SentryWatchdogTerminationScopeObserver

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.fileManager = fileManager;

        self.breadcrumbCounter = 0;
        self.maxBreadcrumbs = maxBreadcrumbs;

        [self switchFileHandle];
    }

    return self;
}

- (void)dealloc
{
    [self.fileHandleBreadcrumbs closeFile];
    [self.fileHandleContext closeFile];
}

// PRAGMA MARK: - Helper methods

- (void)deleteFiles
{
    [self deleteFilesBreadcrumbs];
    [self deleteFilesContexts];
}

- (void)deleteFilesBreadcrumbs
{
    [self.fileHandleBreadcrumbs closeFile];
    self.fileHandleBreadcrumbs = nil;
    self.activeFilePathBreadcrumbs = nil;
    self.breadcrumbCounter = 0;

    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathOne];
    [self.fileManager removeFileAtPath:self.fileManager.breadcrumbsFilePathTwo];
}

- (void)deleteFilesContexts
{
    [self.fileHandleContext closeFile];
    self.fileHandleContext = nil;
    self.activeFilePathContext = nil;

    [self.fileManager removeFileAtPath:self.fileManager.contextFilePathOne];
    [self.fileManager removeFileAtPath:self.fileManager.contextFilePathTwo];
}

- (void)switchFileHandle
{
    [self switchFileHandleBreadcrumbs];
    [self switchFileHandleContexts];
}

- (void)switchFileHandleBreadcrumbs
{
    if ([self.activeFilePathBreadcrumbs isEqualToString:self.fileManager.breadcrumbsFilePathOne]) {
        self.activeFilePathBreadcrumbs = self.fileManager.breadcrumbsFilePathTwo;
    } else {
        self.activeFilePathBreadcrumbs = self.fileManager.breadcrumbsFilePathOne;
    }

    // Close the current filehandle (if any)
    [self.fileHandleBreadcrumbs closeFile];

    // Create a fresh file for the new active path
    [self.fileManager removeFileAtPath:self.activeFilePathBreadcrumbs];
    [[NSFileManager defaultManager] createFileAtPath:self.activeFilePathBreadcrumbs
                                            contents:nil
                                          attributes:nil];

    // Open the file for writing
    self.fileHandleBreadcrumbs =
        [NSFileHandle fileHandleForWritingAtPath:self.activeFilePathBreadcrumbs];

    if (!self.fileHandleBreadcrumbs) {
        SENTRY_LOG_ERROR(@"Couldn't open file handle for %@", self.activeFilePathBreadcrumbs);
    }
}

- (void)switchFileHandleContexts
{
    SENTRY_LOG_DEBUG(@"Switching file handle for context");
    if ([self.activeFilePathContext isEqualToString:self.fileManager.contextFilePathOne]) {
        self.activeFilePathContext = self.fileManager.contextFilePathTwo;
    } else {
        self.activeFilePathContext = self.fileManager.contextFilePathOne;
    }
    SENTRY_LOG_DEBUG(@"New active file path for context: %@", self.activeFilePathContext);

    // Close the current filehandle (if any)
    [self.fileHandleContext closeFile];

    // Create a fresh file for the new active path
    [self.fileManager removeFileAtPath:self.activeFilePathContext];
    [[NSFileManager defaultManager] createFileAtPath:self.activeFilePathContext
                                            contents:nil
                                          attributes:nil];

    // Open the file for writing
    self.fileHandleContext = [NSFileHandle fileHandleForWritingAtPath:self.activeFilePathContext];

    if (!self.fileHandleContext) {
        SENTRY_LOG_ERROR(@"Couldn't open file handle for %@", self.activeFilePathContext);
    }
}

- (void)storeBreadcrumb:(NSData *)data
{
    unsigned long long fileSize;
    @try {
        fileSize = [self.fileHandleBreadcrumbs seekToEndOfFile];

        [self.fileHandleBreadcrumbs writeData:data];
        [self.fileHandleBreadcrumbs writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];

        self.breadcrumbCounter += 1;
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Error while writing data to end file with size (%llu): %@ ", fileSize,
            exception.description);
    } @finally {
        if (self.breadcrumbCounter >= self.maxBreadcrumbs) {
            [self switchFileHandle];
            self.breadcrumbCounter = 0;
        }
    }
}

- (void)storeContext:(NSData *)data
{
    @try {
        SENTRY_LOG_DEBUG(@"Storing context data: %@", data);
        // Override the entire file content by starting from the beginning
        [self.fileHandleContext seekToFileOffset:0];
        [self.fileHandleContext writeData:data];

        // Truncate the file to the current size
        [self.fileHandleContext truncateFileAtOffset:data.length];
        SENTRY_LOG_DEBUG(@"Written context data to file: %@", self.activeFilePathContext);
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Error while writing data to context file: %@", exception.description);
    }
}

// PRAGMA MARK: - SentryScopeObserver

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    if (![NSJSONSerialization isValidJSONObject:crumb]) {
        SENTRY_LOG_ERROR(@"Breadcrumb is not a valid JSON object: %@", crumb);
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:crumb options:0 error:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Error serializing breadcrumb: %@", error);
        return;
    }
    [self storeBreadcrumb:jsonData];
}

- (void)clear
{
    [self clearBreadcrumbs];
}

- (void)clearBreadcrumbs
{
    [self deleteFiles];
    [self switchFileHandle];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    SENTRY_LOG_DEBUG(@"Setting context: %@", context);
    if (![NSJSONSerialization isValidJSONObject:context]) {
        SENTRY_LOG_ERROR(@"Context is not a valid JSON object: %@", context);
        return;
    }

    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:context options:0 error:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Error serializing context: %@", error);
        return;
    }

    [self storeContext:jsonData];
}

- (void)setDist:(nullable NSString *)dist
{
    SENTRY_LOG_DEBUG(@"Setting dist: %@", dist);
}

- (void)setEnvironment:(nullable NSString *)environment
{
    SENTRY_LOG_DEBUG(@"Setting environment: %@", environment);
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    SENTRY_LOG_DEBUG(@"Setting extras: %@", extras);
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    SENTRY_LOG_DEBUG(@"Setting fingerprint: %@", fingerprint);
}

- (void)setLevel:(enum SentryLevel)level
{
    SENTRY_LOG_DEBUG(@"Setting level: %@", @(level));
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    SENTRY_LOG_DEBUG(@"Setting tags: %@", tags);
}

- (void)setUser:(nullable SentryUser *)user
{
    SENTRY_LOG_DEBUG(@"Setting user: %@", user);
}

- (void)setTraceContext:(nullable NSDictionary<NSString *, id> *)traceContext
{
    SENTRY_LOG_DEBUG(@"Setting trace context: %@", traceContext);
}

@end

#endif // SENTRY_HAS_UIKIT
