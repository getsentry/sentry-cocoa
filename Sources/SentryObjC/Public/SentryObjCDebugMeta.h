#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryObjCDebugMeta : NSObject

@property (nonatomic, copy, nullable) NSString *debugID;
@property (nonatomic, copy, nullable) NSString *type;
@property (nonatomic, copy, nullable) NSNumber *imageSize;
@property (nonatomic, copy, nullable) NSString *imageAddress;
@property (nonatomic, copy, nullable) NSString *imageVmAddress;
@property (nonatomic, copy, nullable) NSString *codeFile;

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END
