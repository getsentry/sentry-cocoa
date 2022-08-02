#    pragma clang diagnostic push
#    pragma GCC diagnostic ignored "-Wunused-parameter"
#    pragma GCC diagnostic ignored "-Wshorten-64-to-32"
#    pragma GCC diagnostic ignored "-Wshadow"
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDemangler : NSObject

#if (TARGET_OS_IOS && TARGET_OS_MACCATALYST == 0) || TARGET_OS_TV

- (NSString *)demangleClassName:(NSString *)mangledName;

- (BOOL)isMangled:(NSString *)name;

#endif

@end

NS_ASSUME_NONNULL_END
#    pragma clang diagnostic pop
