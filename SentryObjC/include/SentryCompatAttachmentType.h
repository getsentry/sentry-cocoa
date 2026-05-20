#import <Foundation/Foundation.h>

/// Attachment classification.
typedef NS_ENUM(NSInteger, SentryCompatAttachmentType) {
    SentryCompatAttachmentTypeEventAttachment = 0,
    SentryCompatAttachmentTypeViewHierarchy = 1,
};
