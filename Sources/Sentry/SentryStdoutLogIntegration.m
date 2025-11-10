#import "SentryStdOutLogIntegration.h"
#import "SentryLogC.h"
#import "SentryOptions.h"
#import "SentrySwift.h"
#import <Foundation/Foundation.h>
#import <stdatomic.h>

@interface SentryStdOutLogIntegration ()

@property (strong, nonatomic) NSPipe *stdErrPipe;
@property (strong, nonatomic) NSPipe *stdOutPipe;
@property (nonatomic, copy) void (^logHandler)(NSData *, BOOL isStderr);
@property (nonatomic, assign) int originalStdOut;
@property (nonatomic, assign) int originalStdErr;
@property (strong, nonatomic, nullable) SentryLogger *injectedLogger;
@property (strong, nonatomic, nullable) SentryDispatchFactory *injectedDispatchFactory;
@property (strong, nonatomic, nullable) SentryDispatchQueueWrapper *dispatchQueueWrapper;

@end

// Global atomic flag for infinite loop protection
static _Atomic bool _isForwardingLogs = false;

@implementation SentryStdOutLogIntegration

- (instancetype)init:(SentryDispatchFactory *)dispatchFactory
{
    return [self initWithDispatchFactory:dispatchFactory logger:nil];
}

// Only for testing
- (instancetype)initWithDispatchFactory:(SentryDispatchFactory *)dispatchFactory
                                 logger:(nullable SentryLogger *)logger
{
    if (self = [super init]) {
        self.injectedLogger = logger;
        self.injectedDispatchFactory = dispatchFactory;
    }
    return self;
}

- (SentryLogger *)logger
{
    return self.injectedLogger ?: SentrySDK.logger;
}

- (SentryDispatchFactory *)dispatchFactory
{
    return self.injectedDispatchFactory ?: SentryDependencyContainer.sharedInstance.dispatchFactory;
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

    self.dispatchQueueWrapper =
        [self.dispatchFactory createUtilityQueue:"com.sentry.stdout_log_writing_queue"
                                relativePriority:-3];

    __weak typeof(self) weakSelf = self;
    self.logHandler = ^(NSData *data, BOOL isStderr) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf)
            return;

        if (data && data.length > 0) {
            NSString *logString = [[NSString alloc] initWithData:data
                                                        encoding:NSUTF8StringEncoding];
            if (logString) {
                // Check global atomic flag to avoid infinite loops
                if (atomic_exchange(&_isForwardingLogs, true)) {
                    return; // Already forwarding, break the loop.
                }
                NSDictionary *attributes =
                    @{ @"sentry.log.source" : isStderr ? @"stderr" : @"stdout" };
                if (isStderr) {
                    [strongSelf.logger warn:logString attributes:attributes];
                } else {
                    [strongSelf.logger info:logString attributes:attributes];
                }

                // Clear global atomic flag
                atomic_store(&_isForwardingLogs, false);
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
        self.stdErrPipe.fileHandleForReading.readabilityHandler = nil;

        self.stdOutPipe = nil;
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
            weakSelf.logHandler(data, isStderr);
        }
        [weakSelf.dispatchQueueWrapper dispatchAsyncWithBlock:^{ [newFileHandle writeData:data]; }];
    };

    return pipe;
}

@end
