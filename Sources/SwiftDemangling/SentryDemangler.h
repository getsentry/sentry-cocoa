#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SentryDemangler : NSObject

- (NSString *)demangleClassName:(NSString *)mangledName;

- (BOOL)isMangled:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
