#import <Foundation/Foundation.h>
#if !__has_include(<SentryObjC/SentryObjCDefines.h>)
#    import "SentryObjCDataCollectionHttpBodyType.h"
#else
#    import <SentryObjC/SentryObjCDataCollectionHttpBodyType.h>
#endif

@class SentryObjCDataCollectionKeyValueCollectionBehavior;
@class SentryObjCDataCollectionHttpHeaderCollectionOptions;
@class SentryObjCDataCollectionGraphQLCollectionOptions;
@class SentryObjCDataCollectionDatabaseCollectionOptions;

NS_ASSUME_NONNULL_BEGIN

/// Configuration for what data the SDK collects automatically.
///
/// All properties have spec-defined defaults. Users supply only the options they want to override;
/// omitted fields use the documented defaults.
///
/// Data explicitly set by the user on the scope is not gated by these options.
@interface SentryObjCDataCollectionOptions : NSObject

/// Automatically populate @c user.* fields from auto-instrumentation. Defaults to @c YES.
@property (nonatomic) BOOL userInfo;

/// Controls cookie collection. Defaults to denyList.
@property (nonatomic, strong) SentryObjCDataCollectionKeyValueCollectionBehavior *cookies;

/// Controls HTTP header collection for request and response directions.
@property (nonatomic, strong) SentryObjCDataCollectionHttpHeaderCollectionOptions *httpHeaders;

/// Body types to collect. Defaults to @c SentryObjCDataCollectionHttpBodyTypeAll.
@property (nonatomic) SentryObjCDataCollectionHttpBodyType httpBodies;

/// Controls URL query parameter filtering. Defaults to denyList.
@property (nonatomic, strong) SentryObjCDataCollectionKeyValueCollectionBehavior *queryParams;

/// Controls GraphQL document and variable collection.
@property (nonatomic, strong) SentryObjCDataCollectionGraphQLCollectionOptions *graphql;

/// Controls database query parameter collection.
@property (nonatomic, strong) SentryObjCDataCollectionDatabaseCollectionOptions *database;

/// Include local variable values captured within stack frames. Defaults to @c YES.
@property (nonatomic) BOOL stackFrameVariables;

/// Number of source code lines to include above and below each stack frame. Defaults to @c 5.
@property (nonatomic) NSUInteger frameContextLines;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
