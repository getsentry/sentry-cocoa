#import "SentryInvalidJSONString.h"

NS_ASSUME_NONNULL_BEGIN

@interface SentryInvalidJSONString ()

@property (nonatomic, strong) NSString *stringHolder;
@property (nonatomic, assign) NSUInteger lengthInvocations;
@property (nonatomic, assign) NSUInteger lengthInvocationsToBeInvalid;

@end

@implementation SentryInvalidJSONString

- (instancetype)initWithCharactersNoCopy:(unichar *)characters
                                  length:(NSUInteger)length
                            freeWhenDone:(BOOL)freeBuffer
{
    if (self = [super init]) {
        // Empty on purpose
    }
    return self;
}

- (instancetype)initWithLengthInvocationsToBeInvalid:(NSInteger)lengthInvocationsToBeInvalid
{

    if (self = [super init]) {
        self.lengthInvocations = 0;
        self.lengthInvocationsToBeInvalid = lengthInvocationsToBeInvalid;
    }
    return self;
}

- (NSUInteger)length
{
    // In iOS 26 apple changed the implementation and it may call this method twice when encoding
    // the string to a JSON. We should ignore it if the caller is `__CFStringEncodeByteStream`
    if ([NSThread.callStackSymbols[1] rangeOfString:@"[NSString"].location != NSNotFound) {
        self.lengthInvocations++;
    }

    if (self.lengthInvocations > self.lengthInvocationsToBeInvalid) {
        NSMutableString *invalidString = [NSMutableString stringWithString:@"invalid string"];
        [invalidString appendFormat:@"%C", 0xD800]; // Invalid UTF-16 surrogate pair

        _stringHolder = invalidString;

    } else {
        _stringHolder = @"valid string";
    }

    return self.stringHolder.length;
}

- (unichar)characterAtIndex:(NSUInteger)index
{
    return [self.stringHolder characterAtIndex:index];
}

@end

NS_ASSUME_NONNULL_END
