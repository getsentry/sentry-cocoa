#import "SentryOutOfMemoryScopeObserver.h"
#import <SentryBreadcrumb.h>
#import <SentryFileManager.h>
#import <SentryLog.h>

@interface
SentryOutOfMemoryScopeObserver ()

@property (strong, nonatomic) SentryFileManager *fileManager;
@property (strong, nonatomic) NSFileHandle *fileHandle;

@end

@implementation SentryOutOfMemoryScopeObserver

- (instancetype)initWithMaxBreadcrumbs:(NSInteger)maxBreadcrumbs
                           fileManager:(SentryFileManager *)fileManager
{
    if (self = [super init]) {
        self.fileManager = fileManager;
        [self createFile];
    }

    return self;
}

- (void)dealloc
{
    [self.fileHandle closeFile];
}

// PRAGMA MARK: - Helper methods

- (void)deleteFile
{
    [self.fileHandle closeFile];

    if ([[NSFileManager defaultManager] fileExistsAtPath:self.fileManager.breadcrumbsFilePath]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.breadcrumbsFilePath
                                                   error:&error];
        if (error) {
            SENTRY_LOG_ERROR(@"Couldn't delete file %@", self.fileManager.breadcrumbsFilePath);
        }
    }
}

- (void)createFile
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.fileManager.breadcrumbsFilePath]) {
        [[NSFileManager defaultManager] createFileAtPath:self.fileManager.breadcrumbsFilePath
                                                contents:nil
                                              attributes:nil];
    }

    self.fileHandle =
        [NSFileHandle fileHandleForWritingAtPath:self.fileManager.breadcrumbsFilePath];

    if (!self.fileHandle) {
        SENTRY_LOG_ERROR(@"Couldn't open file handle for %@", self.fileManager.breadcrumbsFilePath);
    }
}

- (void)store:(NSData *)data
{
    [self.fileHandle seekToEndOfFile];
    [self.fileHandle writeData:[@"\n" dataUsingEncoding:NSASCIIStringEncoding]];
    [self.fileHandle writeData:data];
}

// PRAGMA MARK: - SentryScopeObserver

- (void)addSerializedBreadcrumb:(NSDictionary *)crumb
{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:crumb options:0 error:&error];

    if (error) {
        SENTRY_LOG_ERROR(@"Error serializing breadcrumb: %@", error);
    } else {
        [self store:jsonData];
    }
}

- (void)clear
{
    [self clearBreadcrumbs];
}

- (void)clearBreadcrumbs
{
    [self deleteFile];
    [self createFile];
}

- (void)setContext:(nullable NSDictionary<NSString *, id> *)context
{
    // Left blank on purpose
}

- (void)setDist:(nullable NSString *)dist
{
    // Left blank on purpose
}

- (void)setEnvironment:(nullable NSString *)environment
{
    // Left blank on purpose
}

- (void)setExtras:(nullable NSDictionary<NSString *, id> *)extras
{
    // Left blank on purpose
}

- (void)setFingerprint:(nullable NSArray<NSString *> *)fingerprint
{
    // Left blank on purpose
}

- (void)setLevel:(enum SentryLevel)level
{
    // Left blank on purpose
}

- (void)setTags:(nullable NSDictionary<NSString *, NSString *> *)tags
{
    // Left blank on purpose
}

- (void)setUser:(nullable SentryUser *)user
{
    // Left blank on purpose
}

@end
