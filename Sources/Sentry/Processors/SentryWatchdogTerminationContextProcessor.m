#import "SentryWatchdogTerminationContextProcessor.h"

#import "SentryFileManager.h"
#import "SentryLog.h"

@interface SentryWatchdogTerminationContextProcessor ()

@property (strong, nonatomic) SentryFileManager *fileManager;

@property (nonatomic, strong) NSFileHandle *fileHandle;
@property (strong, nonatomic) NSString *activeFilePath;

@end

@implementation SentryWatchdogTerminationContextProcessor

- (instancetype)initWithFileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.fileManager = fileManager;
        self.activeFilePath = fileManager.contextFilePathOne;
    }
    return self;
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

- (void)clear
{
    [self deleteFiles];
}

// MARK: - Helpers

- (void)switchFileHandle
{
    SENTRY_LOG_DEBUG(@"Switching file handle for context");
    if ([self.activeFilePath isEqualToString:self.fileManager.contextFilePathOne]) {
        self.activeFilePath = self.fileManager.contextFilePathTwo;
    } else {
        self.activeFilePath = self.fileManager.contextFilePathOne;
    }
    SENTRY_LOG_DEBUG(@"New active file path for context: %@", self.activeFilePath);

    // Close the current filehandle (if any)
    [self.fileHandle closeFile];

    // Create a fresh file for the new active path
    [self.fileManager removeFileAtPath:self.activeFilePath];
    [[NSFileManager defaultManager] createFileAtPath:self.activeFilePath
                                            contents:nil
                                          attributes:nil];

    // Open the file for writing
    self.fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.activeFilePath];

    if (!self.fileHandle) {
        SENTRY_LOG_ERROR(@"Couldn't open file handle for %@", self.activeFilePath);
    }
}

// MARK: - Helpers

- (void)deleteFiles
{
    [self.fileHandle closeFile];
    self.fileHandle = nil;
    self.activeFilePath = nil;

    [self.fileManager removeFileAtPath:self.fileManager.contextFilePathOne];
    [self.fileManager removeFileAtPath:self.fileManager.contextFilePathTwo];
}

- (void)storeContext:(NSData *)data
{
    @try {
        SENTRY_LOG_DEBUG(@"Storing context data: %@", data);
        // Override the entire file content by starting from the beginning
        [self.fileHandle seekToFileOffset:0];
        [self.fileHandle writeData:data];

        // Truncate the file to the current size
        [self.fileHandle truncateFileAtOffset:data.length];
        SENTRY_LOG_DEBUG(@"Written context data to file: %@", self.activeFilePath);
    } @catch (NSException *exception) {
        SENTRY_LOG_ERROR(@"Error while writing data to context file: %@", exception.description);
    }
}

@end
