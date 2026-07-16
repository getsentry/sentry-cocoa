#if SDK_V10
#    import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Controls database query parameter collection.
@interface SentryObjCDataCollectionDatabaseCollectionOptions : NSObject

/// Whether to collect parameterized database query values. Defaults to @c YES.
@property (nonatomic) BOOL urlQueryParams;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
#endif // SDK_V10
