#import "SentryAppDataSizeObserver.h"

@interface
SentryAppDataSizeObserver ()
@property (strong, nonatomic) NSTimer *updateTimer;
@end

@implementation SentryAppDataSizeObserver

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.appDataSize = -1;

#if TARGET_OS_IOS
        self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:60
                                                            target:self
                                                          selector:@selector(updateAppDataSize)
                                                          userInfo:nil
                                                           repeats:YES];
        // Kick off the calculation immediately
        [self.updateTimer fire];
#endif
    }
    return self;
}

- (void)dealloc
{
    [self.updateTimer invalidate];
}

- (void)updateAppDataSize
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0),
        ^{ self.appDataSize = [self readAppDataSize]; });
}

// Code from https://github.com/NikolaiRuhe/NRFoundation/blob/master/NRFoundation/NRFileManager.m
- (long long)readAppDataSize
{
    // We'll sum up content size here:
    unsigned long long accumulatedSize = 0;

    // Prefetching some properties during traversal will speed up things a bit.
    NSArray *prefetchedProperties = @[
        NSURLIsRegularFileKey,
        NSURLFileAllocatedSizeKey,
        NSURLTotalFileAllocatedSizeKey,
    ];

    // The error handler.
    __block BOOL errorDidOccur = NO;
    BOOL (^errorHandler)(NSURL *, NSError *) = ^(NSURL *url, NSError *localError) {
        errorDidOccur = YES;
        return NO;
    };

    NSDirectoryEnumerator *enumerator =
        [[NSFileManager defaultManager] enumeratorAtURL:[NSURL fileURLWithPath:NSHomeDirectory()]
                             includingPropertiesForKeys:prefetchedProperties
                                                options:(NSDirectoryEnumerationOptions)0
                                           errorHandler:errorHandler];

    // Start the traversal:
    for (NSURL *contentItemURL in enumerator) {
        // Bail out on errors from the errorHandler.
        if (errorDidOccur) {
            return -1;
        }

        // Get the type of this item, making sure we only sum up sizes of regular files.
        NSNumber *isRegularFile;
        if (![contentItemURL getResourceValue:&isRegularFile
                                       forKey:NSURLIsRegularFileKey
                                        error:nil]) {
            return -1;
        }
        if (![isRegularFile boolValue]) {
            continue; // Ignore anything except regular files.
        }

        // To get the file's size we first try the most comprehensive value in terms of what the
        // file may use on disk. This includes metadata, compression (on file system level) and
        // block size.
        NSNumber *fileSize;
        if (![contentItemURL getResourceValue:&fileSize
                                       forKey:NSURLTotalFileAllocatedSizeKey
                                        error:nil]) {
            return -1;
        }

        // In case the value is unavailable we use the fallback value (excluding meta data and
        // compression) This value should always be available.
        if (fileSize == nil) {
            if (![contentItemURL getResourceValue:&fileSize
                                           forKey:NSURLFileAllocatedSizeKey
                                            error:nil]) {
                return -1;
            }

            NSAssert(
                fileSize != nil, @"huh? NSURLFileAllocatedSizeKey should always return a value");
        }

        // We're good, add up the value.
        accumulatedSize += [fileSize unsignedLongLongValue];
    }

    return accumulatedSize;
}

@end
