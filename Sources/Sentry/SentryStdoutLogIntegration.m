#import "SentryStdOutLogIntegration.h"
#import "SentryLogC.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>

@interface SentryStdOutLogIntegration ()

@property (strong, nonatomic) NSPipe *stdErrPipe;
@property (strong, nonatomic) NSPipe *stdOutPipe;
@property (nonatomic, copy) void (^logHandler)(NSData *, BOOL isStderr);
@property (nonatomic, assign) int originalStdOut;
@property (nonatomic, assign) int originalStdErr;

@property (strong, nonatomic) SentryLogger *logger;
@property (strong, nonatomic) SentryDispatchQueueWrapper *dispatchQueue;

@end

@implementation SentryStdOutLogIntegration

// Only for testing
- (instancetype)initWithDispatchQueue:(SentryDispatchQueueWrapper *)dispatchQueue
                               logger:(SentryLogger *)logger
{
    if (self = [super init]) {
        self.logger = logger;
        self.dispatchQueue = dispatchQueue;
    }
    return self;
}

- (BOOL)installWithOptions:(SentryOptions *)options
{
    if (![super installWithOptions:options]) {
        return NO;
    }

    // Only install if logs are enabled
    if (!options.enableLogs) {
        return NO;
    }

    __weak typeof(self) weakSelf = self;
    self.logHandler = ^(NSData *data, BOOL isStderr) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
            return;

        if (data && data.length > 0) {
            NSString *logString = [[NSString alloc] initWithData:data
                                                        encoding:NSUTF8StringEncoding];
            if (logString) {
                // Skip logs from Sentry itself to avoid infinite loops
                if ([logString containsString:@"[Sentry]"]) {
                    return;
                }

                NSDictionary *attributes =
                    @{ @"sentry.log.source" : isStderr ? @"stderr" : @"stdout" };
                if (isStderr) {
                    [strongSelf.logger warn:logString attributes:attributes];
                } else {
                    [strongSelf.logger info:logString attributes:attributes];
                }
            }
        }
    };

    [self start];

    return YES;
}

- (void)start
{
    self.originalStdOut = dup(STDOUT_FILENO);
    self.originalStdErr = dup(STDERR_FILENO);

    self.stdOutPipe = [self duplicateFileDescriptor:STDOUT_FILENO isStderr:NO];
    self.stdErrPipe = [self duplicateFileDescriptor:STDERR_FILENO isStderr:YES];
}

- (void)stop
{
    if (self.stdOutPipe || self.stdErrPipe) {
        // Restore original file descriptors
        if (self.originalStdOut >= 0) {
            dup2(self.originalStdOut, STDOUT_FILENO);
            close(self.originalStdOut);
            self.originalStdOut = -1;
        }

        if (self.originalStdErr >= 0) {
            dup2(self.originalStdErr, STDERR_FILENO);
            close(self.originalStdErr);
            self.originalStdErr = -1;
        }

        // Clean up pipes
        self.stdOutPipe.fileHandleForReading.readabilityHandler = nil;
        self.stdOutPipe = nil;

        self.stdErrPipe.fileHandleForReading.readabilityHandler = nil;
        self.stdErrPipe = nil;

        self.logHandler = nil;
    }
}

- (void)uninstall
{
    [self stop];
}

// Write the input file descriptor to the input file handle, preserving the original output as well.
// This can be used to save stdout/stderr to a file while also keeping it on the console.
- (NSPipe *)duplicateFileDescriptor:(int)fileDescriptor isStderr:(BOOL)isStderr
{
    NSPipe *pipe = [[NSPipe alloc] init];
    int newDescriptor = dup(fileDescriptor);
    NSFileHandle *newFileHandle = [[NSFileHandle alloc] initWithFileDescriptor:newDescriptor
                                                                closeOnDealloc:YES];

    if (dup2(pipe.fileHandleForWriting.fileDescriptor, fileDescriptor) < 0) {
        SENTRY_LOG_ERROR(@"Unable to duplicate file descriptor %d", fileDescriptor);
        close(newDescriptor);
        return nil;
    }

    __weak typeof(self) weakSelf = self;
    pipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (weakSelf.logHandler) {
            [weakSelf.dispatchQueue
                dispatchAsyncWithBlock:^{ weakSelf.logHandler(data, isStderr); }];
        }
        [newFileHandle writeData:data];
    };

    return pipe;
}

@end
