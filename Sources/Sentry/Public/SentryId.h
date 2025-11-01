#import <Foundation/Foundation.h>
#if !defined(SWIFT_CLASS_PROPERTY)
#    if __has_feature(objc_class_property)
#        define SWIFT_CLASS_PROPERTY(...) __VA_ARGS__
#    else
#        define SWIFT_CLASS_PROPERTY(...)
#    endif
#endif

#if !defined(OBJC_DESIGNATED_INITIALIZER)
#    if __has_attribute(objc_designated_initializer)
#        define OBJC_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#    else
#        define OBJC_DESIGNATED_INITIALIZER
#    endif
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SentryId : NSObject

/// A @c SentryId with an empty UUID “00000000000000000000000000000000”.
SWIFT_CLASS_PROPERTY(@property(nonatomic, class, readonly, strong) SentryId *_Nonnull empty;)
+ (SentryId *_Nonnull)empty __attribute__((warn_unused_result));

/// Returns a 32 lowercase character hexadecimal string description of the @c SentryId, such as
/// “12c2d058d58442709aa2eca08bf20986”.
@property (nonatomic, readonly, copy) NSString *_Nonnull sentryIdString;

/// Creates a @c SentryId with a random UUID.
- (nonnull instancetype)init __attribute__((objc_designated_initializer));

/// Creates a SentryId with the given UUID.
- (nonnull instancetype)initWithUuid:(NSUUID *_Nonnull)uuid
    __attribute__((objc_designated_initializer));

/// Creates a @c SentryId from a 32 character hexadecimal string without dashes such as
/// “12c2d058d58442709aa2eca08bf20986” or a 36 character hexadecimal string such as such as
/// “12c2d058-d584-4270-9aa2-eca08bf20986”.
/// @return SentryId.empty for invalid strings.
- (nonnull instancetype)initWithUUIDString:(NSString *_Nonnull)uuidString
    __attribute__((objc_designated_initializer));

- (BOOL)isEqual:(id _Nullable)object __attribute__((warn_unused_result));

@end

NS_ASSUME_NONNULL_END
