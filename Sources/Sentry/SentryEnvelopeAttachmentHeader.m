#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelope+Private.h"

@implementation SentryEnvelopeAttachmentHeader

+ (void)load
{
    printf("%llu %s\n", clock_gettime_nsec_np(CLOCK_UPTIME_RAW), __PRETTY_FUNCTION__);
}

- (instancetype)initWithType:(NSString *)type length:(NSUInteger)length
{
    if (self = [super initWithType:type length:length]) {
        _attachmentType = kSentryAttachmentTypeEventAttachment;
    }
    return self;
}

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType
{

    if (self = [self initWithType:type length:length filenname:filename contentType:contentType]) {
        _attachmentType = attachmentType;
    }
    return self;
}

- (NSDictionary *)serialize
{
    NSMutableDictionary *result = [[super serialize] mutableCopy];
    [result setObject:nameForSentryAttachmentType(self.attachmentType) forKey:@"attachment_type"];
    return result;
}

@end
