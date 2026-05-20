#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Metadata describing a loaded debug image / library.
@interface SentryCompatDebugMeta : NSObject

- (instancetype)init;

@property (nonatomic, copy, nullable) NSString *debugID;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, strong, nullable) NSNumber *imageSize;
@property (nonatomic, copy, nullable) NSString *imageAddress;
@property (nonatomic, copy, nullable) NSString *imageVmAddress;
@property (nonatomic, copy, nullable) NSString *codeFile;

@end

NS_ASSUME_NONNULL_END
