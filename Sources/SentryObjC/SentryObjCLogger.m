#import "SentryObjCLogger.h"

typedef NS_ENUM(NSInteger, SentryObjCLengthModifier) {
    SentryObjCLenNone,
    SentryObjCLenH,
    SentryObjCLenHH,
    SentryObjCLenL,
    SentryObjCLenLL,
    SentryObjCLenZ,
    SentryObjCLenT,
    SentryObjCLenBigL
};

// Parses an NSString format string, extracts typed parameter values from args,
// and produces the formatted body + an attributes dictionary containing
// sentry.message.template and sentry.message.parameter.N entries.
static void
SentryObjCParseFormatString(NSString *format, va_list args, NSString *__autoreleasing *outBody,
    NSMutableDictionary<NSString *, id> *__autoreleasing *outAttributes)
{
    va_list bodyArgs;
    va_copy(bodyArgs, args);
    *outBody = [[NSString alloc] initWithFormat:format arguments:bodyArgs];
    va_end(bodyArgs);

    const char *fmt = [format UTF8String];
    const char *segmentStart = fmt;
    NSMutableString *templateStr = [NSMutableString string];
    NSMutableArray *parameters = [NSMutableArray array];
    int paramIndex = 0;

    while (*fmt) {
        if (*fmt != '%') {
            fmt++;
            continue;
        }

        if (fmt > segmentStart) {
            NSString *segment = [[NSString alloc] initWithBytes:segmentStart
                                                         length:(NSUInteger)(fmt - segmentStart)
                                                       encoding:NSUTF8StringEncoding];
            if (segment) {
                [templateStr appendString:segment];
            }
        }

        fmt++;

        if (*fmt == '%') {
            [templateStr appendString:@"%"];
            fmt++;
            segmentStart = fmt;
            continue;
        }

        // Skip flags
        while (*fmt == '-' || *fmt == '+' || *fmt == '0' || *fmt == ' ' || *fmt == '#'
            || *fmt == '\'') {
            fmt++;
        }

        // Width (* consumes an int arg)
        if (*fmt == '*') {
            (void)va_arg(args, int);
            fmt++;
        } else {
            while (*fmt >= '0' && *fmt <= '9') {
                fmt++;
            }
        }

        // Precision
        if (*fmt == '.') {
            fmt++;
            if (*fmt == '*') {
                (void)va_arg(args, int);
                fmt++;
            } else {
                while (*fmt >= '0' && *fmt <= '9') {
                    fmt++;
                }
            }
        }

        // Length modifier
        SentryObjCLengthModifier lengthMod = SentryObjCLenNone;
        if (*fmt == 'h') {
            fmt++;
            if (*fmt == 'h') {
                lengthMod = SentryObjCLenHH;
                fmt++;
            } else {
                lengthMod = SentryObjCLenH;
            }
        } else if (*fmt == 'l') {
            fmt++;
            if (*fmt == 'l') {
                lengthMod = SentryObjCLenLL;
                fmt++;
            } else {
                lengthMod = SentryObjCLenL;
            }
        } else if (*fmt == 'q') {
            lengthMod = SentryObjCLenLL;
            fmt++;
        } else if (*fmt == 'z') {
            lengthMod = SentryObjCLenZ;
            fmt++;
        } else if (*fmt == 't') {
            lengthMod = SentryObjCLenT;
            fmt++;
        } else if (*fmt == 'L') {
            lengthMod = SentryObjCLenBigL;
            fmt++;
        }

        // Conversion specifier — extract typed arg
        char spec = *fmt;
        if (spec)
            fmt++;

        id paramValue = nil;

        switch (spec) {
        case '@': {
            id obj = va_arg(args, id);
            paramValue = obj ?: @"(null)";
            break;
        }
        case 'd':
        case 'i': {
            switch (lengthMod) {
            case SentryObjCLenLL:
                paramValue = @(va_arg(args, long long));
                break;
            case SentryObjCLenL:
                paramValue = @(va_arg(args, long));
                break;
            case SentryObjCLenZ:
                paramValue = @((long long)va_arg(args, ssize_t));
                break;
            case SentryObjCLenT:
                paramValue = @((long long)va_arg(args, ptrdiff_t));
                break;
            default:
                paramValue = @(va_arg(args, int));
                break;
            }
            break;
        }
        case 'u':
        case 'x':
        case 'X':
        case 'o': {
            switch (lengthMod) {
            case SentryObjCLenLL:
                paramValue = @(va_arg(args, unsigned long long));
                break;
            case SentryObjCLenL:
                paramValue = @(va_arg(args, unsigned long));
                break;
            case SentryObjCLenZ:
                paramValue = @((unsigned long long)va_arg(args, size_t));
                break;
            default:
                paramValue = @(va_arg(args, unsigned int));
                break;
            }
            break;
        }
        case 'f':
        case 'F':
        case 'e':
        case 'E':
        case 'g':
        case 'G':
        case 'a':
        case 'A': {
            if (lengthMod == SentryObjCLenBigL) {
                paramValue = @((double)va_arg(args, long double));
            } else {
                paramValue = @(va_arg(args, double));
            }
            break;
        }
        case 'c': {
            paramValue = [NSString stringWithFormat:@"%c", (char)va_arg(args, int)];
            break;
        }
        case 'C': {
            paramValue = [NSString stringWithFormat:@"%C", (unichar)va_arg(args, int)];
            break;
        }
        case 's': {
            const char *s = va_arg(args, const char *);
            paramValue = s ? [NSString stringWithUTF8String:s] : @"(null)";
            break;
        }
        case 'p': {
            void *ptr = va_arg(args, void *);
            paramValue = [NSString stringWithFormat:@"%p", ptr];
            break;
        }
        default:
            break;
        }

        if (paramValue) {
            [templateStr appendFormat:@"{%d}", paramIndex];
            [parameters addObject:paramValue];
            paramIndex++;
        }

        segmentStart = fmt;
    }

    if (fmt > segmentStart) {
        NSString *segment = [[NSString alloc] initWithBytes:segmentStart
                                                     length:(NSUInteger)(fmt - segmentStart)
                                                   encoding:NSUTF8StringEncoding];
        if (segment) {
            [templateStr appendString:segment];
        }
    }

    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    if (parameters.count > 0) {
        attrs[@"sentry.message.template"] = [templateStr copy];
        for (NSUInteger i = 0; i < parameters.count; i++) {
            attrs[[NSString stringWithFormat:@"sentry.message.parameter.%lu", (unsigned long)i]]
                = parameters[i];
        }
    }

    *outAttributes = attrs;
}

@implementation SentryObjCLogger (FormatString)

// MARK: - Trace

- (void)traceWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self trace:body attributes:attrs];
}

- (void)traceWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self trace:body attributes:attrs];
}

// MARK: - Debug

- (void)debugWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self debug:body attributes:attrs];
}

- (void)debugWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self debug:body attributes:attrs];
}

// MARK: - Info

- (void)infoWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self info:body attributes:attrs];
}

- (void)infoWithAttributes:(NSDictionary<NSString *, id> *)attributes format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self info:body attributes:attrs];
}

// MARK: - Warn

- (void)warnWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self warn:body attributes:attrs];
}

- (void)warnWithAttributes:(NSDictionary<NSString *, id> *)attributes format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self warn:body attributes:attrs];
}

// MARK: - Error

- (void)errorWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self error:body attributes:attrs];
}

- (void)errorWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self error:body attributes:attrs];
}

// MARK: - Fatal

- (void)fatalWithFormat:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [self fatal:body attributes:attrs];
}

- (void)fatalWithAttributes:(NSDictionary<NSString *, id> *)attributes
                     format:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSString *body;
    NSMutableDictionary *attrs;
    SentryObjCParseFormatString(format, args, &body, &attrs);
    va_end(args);
    [attrs addEntriesFromDictionary:attributes];
    [self fatal:body attributes:attrs];
}

@end
