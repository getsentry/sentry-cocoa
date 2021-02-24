#import "SentrySessionRecorder.h"
#import "ScreenRecorder.h"

@implementation SentrySessionRecorder {
    BOOL started;
    NSURL *currentName;
}

- (instancetype)init
{
    self = [super init];
    return self;
}

- (bool)start
{
    if (!started) {
        if ((started = [self startNext]))
            [NSNotificationCenter.defaultCenter addObserver:self
                                                   selector:@selector(recordFinished)
                                                       name:@"io.sentry.RECORD_ENDED"
                                                     object:nil];
    }
    return started;
}

- (void)stop
{
    if (started) {
        started = false;
        [ScreenRecorder.shared finish];
    }
    [NSNotificationCenter.defaultCenter removeObserver:self
                                                  name:@"io.sentry.RECORD_ENDED"
                                                object:nil];
}

- (bool)startNext
{
    [self clearDirectory];

    dispatch_async(dispatch_get_main_queue(), ^{
        self->currentName = [self nextName];
        [ScreenRecorder.shared startWithTarget:self->currentName duration:10];
    });

    return true;
}

- (void)recordFinished
{
    if (started)
        [self startNext];
}

- (void)clearDirectory
{
    NSString *dir = [self sessionDirectory];
    NSArray<NSString *> *files = [self availableRecording];
    if (files.count > 5) {
        for (int i = 0; i < -(5 - files.count); i++) {
            [NSFileManager.defaultManager
                removeItemAtPath:[dir stringByAppendingPathComponent:files[i]]
                           error:nil];
        }
    }
}

- (NSURL *)nextName
{
    NSString *sessionsDirectory = [self sessionDirectory];

    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"YYYY-MM-dd_HHmmss"];
    NSString *today = [dateFormat stringFromDate:NSDate.date];

    NSString *filePath = [[sessionsDirectory stringByAppendingPathComponent:today]
        stringByAppendingPathExtension:@"mp4"];
    NSLog(@"%@", filePath);

    return [NSURL fileURLWithPath:filePath];
}

- (NSString *)sessionDirectory
{
    NSArray *paths
        = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *sessionsDirectory =
        [[paths objectAtIndex:0] stringByAppendingPathComponent:@"sessions"];
    if (![NSFileManager.defaultManager fileExistsAtPath:sessionsDirectory]) {
        [NSFileManager.defaultManager createDirectoryAtPath:sessionsDirectory
                                withIntermediateDirectories:true
                                                 attributes:nil
                                                      error:nil];
    }
    return sessionsDirectory;
}

- (NSArray *)availableRecording
{
    NSArray *files = [[NSFileManager.defaultManager
        contentsOfDirectoryAtPath:[self sessionDirectory]
                            error:nil]
        filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *evaluatedObject,
                                        NSDictionary<NSString *, id> *bindings) {
            return [evaluatedObject hasSuffix:@".mp4"];
        }]];

    return [files sortedArrayUsingComparator:^NSComparisonResult(
        id _Nonnull obj1, id _Nonnull obj2) { return [obj1 compare:obj2]; }];
}

- (nullable NSURL *)fileUrlForRecording:(NSString *)recordName
{
    NSString *path = [[self sessionDirectory] stringByAppendingPathComponent:recordName];
    if ([NSFileManager.defaultManager fileExistsAtPath:path]) {
        return [NSURL fileURLWithPath:path];
    }
    return NULL;
}

- (NSURL *)currentRecording
{
    NSURL *url = NULL;
    NSTimeInterval length = [ScreenRecorder.shared recordingLength];
    if (length > 1) {
        url = currentName;
        [ScreenRecorder.shared finish];
        [NSThread sleepForTimeInterval:1]; // Hack just for now, to give time to finish saving video
    } else {
        NSArray<NSString *> *records = [self availableRecording];
        if (records.count > 1) {
            url = [NSURL
                fileURLWithPath:[[self sessionDirectory]
                                    stringByAppendingPathComponent:records[records.count - 2]]];
        }
    }

    return url;
}

+ (SentrySessionRecorder *)shared
{
    static SentrySessionRecorder *_shared;
    if (_shared == nil) {
        _shared = [[SentrySessionRecorder alloc] init];
    }
    return _shared;
}

- (BOOL)isRecording
{
    return ScreenRecorder.shared.isRecording;
}

@end
