#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDemangler : NSObject

#if (TARGET_OS_IOS && TARGET_OS_MACCATALYST == 0) || TARGET_OS_TV

- (NSString *)demangleClassName:(NSString *)mangledName;

- (BOOL)isMangled:(NSString *)name;

#endif

@end

NS_ASSUME_NONNULL_END
