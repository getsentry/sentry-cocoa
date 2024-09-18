#import "SentryScope.h"

@class SentryUser;
@class SentryBreadcrumb;
@class SentryAttachment;

NS_ASSUME_NONNULL_BEGIN

/** Expose the internal properties for testing. */
@interface
SentryScope (Properties)

@property (atomic, strong) SentryUser *_Nullable userObject;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *_Nullable tagDictionary;
@property (nonatomic, strong) NSMutableDictionary<NSString *, id> *_Nullable extraDictionary;
@property (nonatomic, strong)
    NSMutableDictionary<NSString *, NSDictionary<NSString *, id> *> *_Nullable contextDictionary;
@property (nonatomic, strong) NSMutableArray<SentryBreadcrumb *> *breadcrumbArray;
@property (atomic, copy) NSString *_Nullable distString;
@property (atomic, copy) NSString *_Nullable environmentString;
@property (atomic, strong) NSArray<NSString *> *_Nullable fingerprintArray;
@property (atomic) enum SentryLevel levelEnum;
@property (atomic) NSInteger maxBreadcrumbs;
@property (atomic, strong) NSMutableArray<SentryAttachment *> *attachmentArray;

@end

NS_ASSUME_NONNULL_END
