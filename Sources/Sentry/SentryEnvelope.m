#import "SentryAttachment.h"
#import "SentryBreadcrumb.h"
#import "SentryClientReport.h"
#import "SentryDateUtils.h"
#import "SentryEnvelope+Private.h"
#import "SentryEnvelopeAttachmentHeader.h"
#import "SentryEnvelopeItemHeader.h"
#import "SentryEnvelopeItemType.h"
#import "SentryEvent.h"
#import "SentryLogC.h"
#import "SentryMessage.h"
#import "SentryMsgPackSerializer.h"
#import "SentrySdkInfo.h"
#import "SentrySerialization.h"
#import "SentrySession.h"
#import "SentrySwift.h"
#import "SentryTransaction.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SentryEnvelopeHeader

// id can be null if no event in the envelope or attachment related to event
- (instancetype)initWithId:(SentryId *_Nullable)eventId
{
    self = [self initWithId:eventId traceContext:nil];
    return self;
}

- (instancetype)initWithId:(nullable SentryId *)eventId
              traceContext:(nullable SentryTraceContext *)traceContext
{
    SentrySdkInfo *sdkInfo = [SentrySdkInfo global];
    self = [self initWithId:eventId sdkInfo:sdkInfo traceContext:traceContext];
    return self;
}

- (instancetype)initWithId:(nullable SentryId *)eventId
                   sdkInfo:(nullable SentrySdkInfo *)sdkInfo
              traceContext:(nullable SentryTraceContext *)traceContext
{
    if (self = [super init]) {
        _eventId = eventId;
        _sdkInfo = sdkInfo;
        _traceContext = traceContext;
    }

    return self;
}

+ (instancetype)empty
{
    return [[SentryEnvelopeHeader alloc] initWithId:nil traceContext:nil];
}

@end

@implementation SentryEnvelopeItem

- (instancetype)initWithHeader:(SentryEnvelopeItemHeader *)header data:(NSData *)data
{
    if (self = [super init]) {
        _header = header;
        _data = data;
    }
    return self;
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    NSData *json = [SentrySerialization dataWithJSONObject:[event serialize]];

    if (nil == json) {
        // We don't know what caused the serialization to fail.
        SentryEvent *errorEvent = [[SentryEvent alloc] initWithLevel:kSentryLevelWarning];

        // Add some context to the event. We can only set simple properties otherwise we
        // risk that the conversion fails again.
        NSString *message = [NSString
            stringWithFormat:@"JSON conversion error for event with message: '%@'", event.message];

        errorEvent.message = [[SentryMessage alloc] initWithFormatted:message];
        errorEvent.releaseName = event.releaseName;
        errorEvent.environment = event.environment;
        errorEvent.platform = event.platform;
        errorEvent.timestamp = event.timestamp;

        // We accept the risk that this simple serialization fails. Therefore we ignore the
        // error on purpose.
        json = [SentrySerialization dataWithJSONObject:[errorEvent serialize]];
    }

    // event.type can be nil and the server infers error if there's a stack trace, otherwise
    // default. In any case in the envelope type it should be event. Except for transactions
    NSString *envelopeType = [event.type isEqualToString:SentryEnvelopeItemTypeTransaction]
        ? SentryEnvelopeItemTypeTransaction
        : [event.type isEqualToString:SentryEnvelopeItemTypeFeedback]
        ? SentryEnvelopeItemTypeFeedback
        : SentryEnvelopeItemTypeEvent;

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:envelopeType
                                                                        length:json.length]
                           data:json];
}

- (instancetype)initWithSession:(SentrySession *)session
{
    NSData *json = [NSJSONSerialization dataWithJSONObject:[session serialize] options:0 error:nil];
    return [self
        initWithHeader:[[SentryEnvelopeItemHeader alloc] initWithType:SentryEnvelopeItemTypeSession
                                                               length:json.length]
                  data:json];
}

#if !SDK_V9
- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
{
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:[userFeedback serialize]
                                                   options:0
                                                     error:&error];

    if (nil != error) {
        SENTRY_LOG_ERROR(@"Couldn't serialize user feedback.");
        json = [NSData new];
    }

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeUserFeedback
                                          length:json.length]
                           data:json];
}
#endif // !SDK_V9

- (instancetype)initWithClientReport:(SentryClientReport *)clientReport
{
    NSError *error = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:[clientReport serialize]
                                                   options:0
                                                     error:&error];

    if (nil != error) {
        SENTRY_LOG_ERROR(@"Couldn't serialize client report.");
        json = [NSData new];
    }

    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeClientReport
                                          length:json.length]
                           data:json];
}

- (_Nullable instancetype)initWithAttachment:(SentryAttachment *)attachment
                           maxAttachmentSize:(NSUInteger)maxAttachmentSize
{
    NSData *data = nil;
    if (nil != attachment.data) {
        if (attachment.data.length > maxAttachmentSize) {
            SENTRY_LOG_DEBUG(
                @"Dropping attachment with filename '%@', because the size of the passed data with "
                @"%lu bytes is bigger than the maximum allowed attachment size of %lu bytes.",
                attachment.filename, (unsigned long)attachment.data.length,
                (unsigned long)maxAttachmentSize);
            return nil;
        }

#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if ([NSProcessInfo.processInfo.arguments
                containsObject:@"--io.sentry.other.base64-attachment-data"]) {
            data = [[attachment.data base64EncodedStringWithOptions:0]
                dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            data = attachment.data;
        }
#else
        data = attachment.data;
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    } else if (nil != attachment.path) {

        NSError *error = nil;
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSDictionary<NSFileAttributeKey, id> *attr =
            [fileManager attributesOfItemAtPath:attachment.path error:&error];

        if (nil != error) {
            SENTRY_LOG_ERROR(@"Couldn't check file size of attachment with path: %@. Error: %@",
                attachment.path, error.localizedDescription);

            return nil;
        }

        unsigned long long fileSize = [attr fileSize];

        if (fileSize > maxAttachmentSize) {
            SENTRY_LOG_DEBUG(
                @"Dropping attachment, because the size of the it located at '%@' with %llu bytes "
                @"is bigger than the maximum allowed attachment size of %lu bytes.",
                attachment.path, fileSize, (unsigned long)maxAttachmentSize);
            return nil;
        }

#if DEBUG || SENTRY_TEST || SENTRY_TEST_CI
        if ([NSProcessInfo.processInfo.arguments
                containsObject:@"--io.sentry.other.base64-attachment-data"]) {
            data = [[[[NSFileManager defaultManager] contentsAtPath:attachment.path]
                base64EncodedStringWithOptions:0] dataUsingEncoding:NSUTF8StringEncoding];
        } else {
            data = [[NSFileManager defaultManager] contentsAtPath:attachment.path];
        }
#else
        data = [[NSFileManager defaultManager] contentsAtPath:attachment.path];
#endif // DEBUG || SENTRY_TEST || SENTRY_TEST_CI
    }

    if (data == nil) {
        SENTRY_LOG_ERROR(@"Couldn't init Attachment.");
        return nil;
    }

    SentryEnvelopeItemHeader *itemHeader =
        [[SentryEnvelopeAttachmentHeader alloc] initWithType:SentryEnvelopeItemTypeAttachment
                                                      length:data.length
                                                    filename:attachment.filename
                                                 contentType:attachment.contentType
                                              attachmentType:attachment.attachmentType];

    return [self initWithHeader:itemHeader data:data];
}

- (nullable instancetype)initWithReplayEvent:(SentryReplayEvent *)replayEvent
                             replayRecording:(SentryReplayRecording *)replayRecording
                                       video:(NSURL *)videoURL
{
    NSData *replayEventData = [SentrySerialization dataWithJSONObject:[replayEvent serialize]];
    NSData *recording = [SentrySerialization dataWithReplayRecording:replayRecording];
    NSURL *envelopeContentUrl =
        [[videoURL URLByDeletingPathExtension] URLByAppendingPathExtension:@"dat"];

    BOOL success = [SentryMsgPackSerializer serializeDictionaryToMessagePack:@{
        @"replay_event" : replayEventData,
        @"replay_recording" : recording,
        @"replay_video" : videoURL
    }
                                                                    intoFile:envelopeContentUrl];
    if (success == NO) {
        SENTRY_LOG_ERROR(@"Could not create MessagePack for session replay envelope item.");
        return nil;
    }

    NSData *envelopeItemContent = [NSData dataWithContentsOfURL:envelopeContentUrl];

    NSError *error;
    if (![NSFileManager.defaultManager removeItemAtURL:envelopeContentUrl error:&error]) {
        SENTRY_LOG_ERROR(@"Cound not delete temporary replay content from disk: %@", error);
    }
    return [self initWithHeader:[[SentryEnvelopeItemHeader alloc]
                                    initWithType:SentryEnvelopeItemTypeReplayVideo
                                          length:envelopeItemContent.length]
                           data:envelopeItemContent];
}

@end

@implementation SentryEnvelope

- (instancetype)initWithSession:(SentrySession *)session
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithSession:session];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] singleItem:item];
}

- (instancetype)initWithSessions:(NSArray<SentrySession *> *)sessions
{
    NSMutableArray *envelopeItems = [[NSMutableArray alloc] initWithCapacity:sessions.count];
    for (int i = 0; i < sessions.count; ++i) {
        SentryEnvelopeItem *item =
            [[SentryEnvelopeItem alloc] initWithSession:[sessions objectAtIndex:i]];
        [envelopeItems addObject:item];
    }
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:nil] items:envelopeItems];
}

- (instancetype)initWithEvent:(SentryEvent *)event
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithEvent:event];
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:event.eventId]
                     singleItem:item];
}

#if !SDK_V9
- (instancetype)initWithUserFeedback:(SentryUserFeedback *)userFeedback
{
    SentryEnvelopeItem *item = [[SentryEnvelopeItem alloc] initWithUserFeedback:userFeedback];

    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:userFeedback.eventId]
                     singleItem:item];
}
#endif // !SDK_V9

- (instancetype)initWithId:(SentryId *_Nullable)id singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] singleItem:item];
}

- (instancetype)initWithId:(SentryId *_Nullable)id items:(NSArray<SentryEnvelopeItem *> *)items
{
    return [self initWithHeader:[[SentryEnvelopeHeader alloc] initWithId:id] items:items];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header singleItem:(SentryEnvelopeItem *)item
{
    return [self initWithHeader:header items:@[ item ]];
}

- (instancetype)initWithHeader:(SentryEnvelopeHeader *)header
                         items:(NSArray<SentryEnvelopeItem *> *)items
{
    if (self = [super init]) {
        _header = header;
        _items = items;
    }
    return self;
}

- (NSString *)debugDescription
{
    return [self logEnvelopeContents];
}

- (NSString *)logEnvelopeContents
{
    NSMutableString *output =
        [NSMutableString stringWithString:@"===Begin raw envelope contents===\n"];

    // Log envelope header
    NSMutableDictionary *headerDict = [NSMutableDictionary new];
    if (self.header.eventId) {
        headerDict[@"event_id"] = self.header.eventId.sentryIdString;
    }
    if (self.header.sdkInfo) {
        headerDict[@"sdk"] = [self.header.sdkInfo serialize];
    }
    if (self.header.traceContext) {
        headerDict[@"trace"] = [self.header.traceContext serialize];
    }
    if (self.header.sentAt) {
        headerDict[@"sent_at"] = sentry_toIso8601String(self.header.sentAt);
    }

    NSData *headerData = [SentrySerialization dataWithJSONObject:headerDict];
    if (headerData) {
        NSString *headerString = [[NSString alloc] initWithData:headerData
                                                       encoding:NSUTF8StringEncoding];
        if (headerString) {
            [output appendFormat:@"%@\n", headerString];
        }
    }

    // Log envelope items
    for (SentryEnvelopeItem *item in self.items) {
        // Log item header
        NSDictionary *itemHeaderDict = [item.header serialize];
        NSData *itemHeaderData = [SentrySerialization dataWithJSONObject:itemHeaderDict];
        if (itemHeaderData) {
            NSString *itemHeaderString = [[NSString alloc] initWithData:itemHeaderData
                                                               encoding:NSUTF8StringEncoding];
            if (itemHeaderString) {
                [output appendFormat:@"%@\n", itemHeaderString];
            }
        }

        // Log item payload
        NSString *itemType = item.header.type;

        if ([itemType isEqualToString:SentryEnvelopeItemTypeEvent] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeTransaction] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeSession] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeFeedback] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeClientReport] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeProfile] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeProfileChunk] ||
            [itemType isEqualToString:SentryEnvelopeItemTypeLog]) {
            // JSON payloads - log the actual JSON
            NSString *jsonString = [[NSString alloc] initWithData:item.data
                                                         encoding:NSUTF8StringEncoding];
            if (jsonString) {
                [output appendFormat:@"%@\n", jsonString];
            } else {
                [output appendString:@"<invalid UTF-8 JSON data>\n"];
            }
        } else if ([itemType isEqualToString:SentryEnvelopeItemTypeAttachment]) {
            // For attachments, show summary since the data might be binary
            NSString *attachmentOutput = [self getAttachmentOutput:item.data header:item.header];
            [output appendString:attachmentOutput];
        } else {
            // Binary or non-JSON payload - try to show as text, otherwise hex
            NSString *textString = [[NSString alloc] initWithData:item.data
                                                         encoding:NSUTF8StringEncoding];
            if (textString) {
                [output appendFormat:@"%@\n", textString];
            } else {
                // Show hex dump for binary data
                NSString *hexPreview = [self getDataPreview:item.data maxLength:200];
                [output appendFormat:@"%@\n", hexPreview];
            }
        }
    }

    [output appendString:@"===End raw envelope contents==="];

    return output;
}

- (NSString *)getAttachmentOutput:(NSData *)data header:(SentryEnvelopeItemHeader *)header
{
    NSString *contentType = header.contentType ?: @"unknown";
    NSString *filename = header.filename ?: @"<no filename>";

    NSMutableDictionary *attachmentSummary =
        [@{ @"filename" : filename, @"content_type" : contentType, @"size" : @(data.length) }
            mutableCopy];

    if ([contentType hasPrefix:@"text/"] || [contentType isEqualToString:@"application/json"] ||
        [contentType hasPrefix:@"application/x-"]) {
        // Try to display as text
        NSString *textContent = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (textContent) {
            NSArray *lines = [textContent componentsSeparatedByString:@"\n"];
            NSUInteger maxLines = MIN([lines count], 5);
            NSMutableArray *sampleLines = [NSMutableArray array];

            for (NSUInteger i = 0; i < maxLines; i++) {
                NSString *line = lines[i];
                if ([line length] > 100) {
                    line = [[line substringToIndex:100] stringByAppendingString:@"..."];
                }
                [sampleLines addObject:line];
            }

            attachmentSummary[@"content_preview"] = sampleLines;
            if ([lines count] > maxLines) {
                attachmentSummary[@"remaining_lines"] = @([lines count] - maxLines);
            }
        } else {
            NSString *preview = [self getDataPreview:data maxLength:100];
            attachmentSummary[@"content_preview"] = preview;
        }
    } else {
        NSString *preview = [self getDataPreview:data maxLength:100];
        attachmentSummary[@"content_preview"] = preview;
    }

    // Serialize with pretty printing
    NSError *error;
    NSData *summaryData =
        [NSJSONSerialization dataWithJSONObject:@{ @"attachment" : attachmentSummary }
                                        options:0
                                          error:&error];
    if (summaryData && !error) {
        NSString *summaryString = [[NSString alloc] initWithData:summaryData
                                                        encoding:NSUTF8StringEncoding];
        return [summaryString stringByAppendingString:@"\n"];
    } else {
        return [NSString stringWithFormat:@"Failed to serialize attachment summary: %@\n",
            error.localizedDescription];
    }
}

- (NSString *)getDataPreview:(NSData *)data maxLength:(NSUInteger)maxLength
{
    if (data.length == 0) {
        return @"<empty>";
    }

    // First try to decode as UTF-8 string
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (string) {
        if ([string length] <= maxLength) {
            return [NSString stringWithFormat:@"\"%@\"", string];
        } else {
            NSString *truncated = [string substringToIndex:maxLength];
            return [NSString stringWithFormat:@"\"%@...\" (%lu total chars)", truncated,
                (unsigned long)[string length]];
        }
    }

    // If not valid UTF-8, show as hex dump
    const unsigned char *bytes = [data bytes];
    NSMutableString *hexString = [NSMutableString string];
    NSUInteger displayLength = MIN(data.length, maxLength / 2); // 2 chars per byte in hex

    for (NSUInteger i = 0; i < displayLength; i++) {
        [hexString appendFormat:@"%02x", bytes[i]];
        if (i < displayLength - 1 && (i + 1) % 16 == 0) {
            [hexString appendString:@"\n      "];
        } else if (i < displayLength - 1 && (i + 1) % 4 == 0) {
            [hexString appendString:@" "];
        }
    }

    if (data.length > displayLength) {
        [hexString appendFormat:@"... (%lu total bytes)", (unsigned long)data.length];
    }

    return [NSString stringWithFormat:@"Binary data:\n      %@", hexString];
}

@end

NS_ASSUME_NONNULL_END
