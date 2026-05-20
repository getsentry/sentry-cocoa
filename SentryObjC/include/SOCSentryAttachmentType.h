#import <Foundation/Foundation.h>

/// Attachment classification.
typedef NS_ENUM(NSInteger, SOCSentryAttachmentType) {
    SOCSentryAttachmentTypeEventAttachment = 0,
    SOCSentryAttachmentTypeViewHierarchy = 1,
};
