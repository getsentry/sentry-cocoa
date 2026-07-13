#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Controls GraphQL document and variable collection.
@interface SentryObjCDataCollectionGraphQLCollectionOptions : NSObject

/// Whether to collect GraphQL query/mutation documents. Defaults to @c YES.
@property (nonatomic) BOOL document;

/// Whether to collect GraphQL variables. Defaults to @c YES.
@property (nonatomic) BOOL variables;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
