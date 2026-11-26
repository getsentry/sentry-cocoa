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
    // Prior to some version after *OS 26 Apple changed the implementation of
    // `__CFStringEncodeByteStream` Previously, `length` was only called from
    // `-[NSString(NSStringOtherEncodings) dataUsingEncoding:allowLossyConversion:] but now it is
    // called also called by `__CFStringEncodeByteStream`. In *OS 27 `+[_NSJSONReader
    // validForJSON:depth:allowFragments]` also calls length _before_
    // `__CFStringEncodeByteStream does. To avoid counting an invocation more than once we ignore
    // them.

    NSArray<NSString *> *ignoredSymbols =
        @[ @"__CFStringEncodeByteStream", @"+[_NSJSONReader validForJSON:depth:allowFragments:]" ];

    NSString *callStackSymbol = NSThread.callStackSymbols[1];

    BOOL shouldIgnoreInvocation = NO;
    for (NSString *symbol in ignoredSymbols) {
        if ([callStackSymbol containsString:symbol]) {
            shouldIgnoreInvocation = YES;
        }
    }

    if (!shouldIgnoreInvocation) {
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
