#import "SentrySpanDataKey.h"

NSString *const SentrySpanDataKeyFileSize = @"file.size";
NSString *const SentrySpanDataKeyFilePath = @"file.path";

@implementation SentrySpanDataKey
+ (NSString *)fileSize
{
    return SentrySpanDataKeyFileSize;
}

+ (NSString *)filePath
{
    return SentrySpanDataKeyFilePath;
}
@end
