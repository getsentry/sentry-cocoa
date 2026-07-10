#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Controls database query parameter collection.
@interface SentryObjCDataCollectionDatabaseCollectionOptions : NSObject

/// Whether to collect parameterized database query values. Defaults to @c YES.
@property (nonatomic) BOOL queryParams;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
