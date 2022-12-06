#import "SentryAttachment.h"
#import "SentryEnvelope.h"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryEnvelopeAttachmentHeader : SentryEnvelopeItemHeader

@property (nonatomic, readonly) SentryAttachmentType attachmentType;

- (instancetype)initWithType:(NSString *)type
                      length:(NSUInteger)length
                    filename:(NSString *)filename
                 contentType:(NSString *)contentType
              attachmentType:(SentryAttachmentType)attachmentType;

@end

@interface
SentryEnvelopeItem (Private)

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport;

@end

NS_ASSUME_NONNULL_END
