#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSURLProtocolSwizzle : NSObject

typedef void (^ClassCallback)(Class _Nullable callbackClass);

@property (class, nonatomic, readonly) NSURLProtocolSwizzle *shared;

@property (nullable, nonatomic, strong) ClassCallback registerCallback;

@property (nullable, nonatomic, strong) ClassCallback unregisterCallback;

+ (void)swizzleURLProtocol;

@end

NS_ASSUME_NONNULL_END
