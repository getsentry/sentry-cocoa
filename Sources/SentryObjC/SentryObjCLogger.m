#import "SentryObjCLogger.h"
#import <stdint.h>

// ──────────────────────────────────────────────────────────────────────────────
// NSString format string parser
//
// Reference: Apple "String Format Specifiers"
// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/Strings/Articles/formatSpecifiers.html
//
// NSString follows the IEEE printf specification plus %@ for Objective-C
// objects. Positional specifiers (n$, e.g. %1$@ %2$s) are supported by
// NSString but are NOT handled by this parserm because C's va_list is a
// forward-only cursor and va_arg consumes the next argument sequentially
// with no way to rewind, skip, or index.
//
// Positional specifiers reference arguments in arbitrary order
// (e.g. %2$@ before %1$d), so supporting them would require a two-pass
// approach: first scan the entire format string to build a type map for
// every positional index, then consume va_arg sequentially using that map.
// This is significant complexity for a feature rarely used outside localized
// strings, which are not typical for structured log messages. NS_FORMAT_FUNCTION
// on our public API ensures the compiler validates format strings at the
// call site regardless.
//
// Table 1 — Format specifiers
// ┌────────┬────────────────────────────────────────────────────────────────┐
// │  %@    │ Objective-C object (descriptionWithLocale: or description)     │
// │  %%    │ Literal '%' character                                          │
// │  %d %D │ Signed 32-bit integer (int)                                    │
// │  %u %U │ Unsigned 32-bit integer (unsigned int)                         │
// │  %x    │ Unsigned 32-bit integer, hex lowercase a-f                     │
// │  %X    │ Unsigned 32-bit integer, hex uppercase A-F                     │
// │  %o %O │ Unsigned 32-bit integer, octal                                 │
// │  %f    │ 64-bit floating-point (double)                                 │
// │  %F    │ 64-bit floating-point (double), decimal notation               │
// │  %e    │ 64-bit floating-point (double), scientific lowercase e         │
// │  %E    │ 64-bit floating-point (double), scientific uppercase E         │
// │  %g    │ 64-bit floating-point (double), shorter of %e or %f            │
// │  %G    │ 64-bit floating-point (double), shorter of %E or %f            │
// │  %a    │ 64-bit floating-point (double), hex with lowercase p exponent  │
// │  %A    │ 64-bit floating-point (double), hex with uppercase P exponent  │
// │  %c    │ 8-bit unsigned character (unsigned char)                       │
// │  %C    │ 16-bit UTF-16 code unit (unichar)                              │
// │  %s    │ Null-terminated array of 8-bit unsigned characters             │
// │  %S    │ Null-terminated array of 16-bit UTF-16 code units              │
// │  %p    │ Void pointer (void *), hex with leading 0x                     │
// └────────┴────────────────────────────────────────────────────────────────┘
//
// Table 2 — Length modifiers
// ┌────────┬────────────────────────────────────────────────────────────────┐
// │  h     │ short / unsigned short (applies to d, o, u, x, X)              │
// │  hh    │ signed char / unsigned char (applies to d, o, u, x, X)         │
// │  l     │ long / unsigned long (applies to d, o, u, x, X)                │
// │  ll, q │ long long / unsigned long long (applies to d, o, u, x, X)      │
// │  z     │ size_t (applies to d, o, u, x, X)                              │
// │  t     │ ptrdiff_t (applies to d, o, u, x, X)                           │
// │  j     │ intmax_t / uintmax_t (applies to d, o, u, x, X)                │
// │  L     │ long double (applies to a, A, e, E, f, F, g, G)                │
// └────────┴────────────────────────────────────────────────────────────────┘

typedef NS_ENUM(NSInteger, SentryObjCLengthModifier) {
    SentryObjCLenNone,
    SentryObjCLenH, // h  — short / unsigned short
    SentryObjCLenHH, // hh — signed char / unsigned char
    SentryObjCLenL, // l  — long / unsigned long
    SentryObjCLenLL, // ll, q — long long / unsigned long long
    SentryObjCLenZ, // z  — size_t
    SentryObjCLenT, // t  — ptrdiff_t
    SentryObjCLenJ, // j  — intmax_t / uintmax_t
    SentryObjCLenBigL // L  — long double
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
    NSMutableArray *parameters = [NSMutableArray array];

    while (*fmt) {
        if (*fmt != '%') {
            fmt++;
            continue;
        }

        fmt++; // skip '%'

        // %% — literal '%' character
        if (*fmt == '%') {
            fmt++;
            continue;
        }

        // Flags: '-' left-justify, '+' sign, '0' zero-pad, ' ' space, '#' alternate, '\'' grouping
        while (*fmt == '-' || *fmt == '+' || *fmt == '0' || *fmt == ' ' || *fmt == '#'
            || *fmt == '\'') {
            fmt++;
        }

        // Width — literal digits or '*' (consumes an int arg from va_list)
        if (*fmt == '*') {
            (void)va_arg(args, int);
            fmt++;
        } else {
            while (*fmt >= '0' && *fmt <= '9') {
                fmt++;
            }
        }

        // Precision — '.' followed by digits or '*' (consumes an int arg from va_list)
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

        // Length modifier (Table 2)
        SentryObjCLengthModifier lengthMod = SentryObjCLenNone;
        if (*fmt == 'h') {
            fmt++;
            if (*fmt == 'h') {
                // hh — signed char / unsigned char
                lengthMod = SentryObjCLenHH;
                fmt++;
            } else {
                // h — short / unsigned short
                lengthMod = SentryObjCLenH;
            }
        } else if (*fmt == 'l') {
            fmt++;
            if (*fmt == 'l') {
                // ll — long long / unsigned long long
                lengthMod = SentryObjCLenLL;
                fmt++;
            } else {
                // l — long / unsigned long
                lengthMod = SentryObjCLenL;
            }
        } else if (*fmt == 'q') {
            // q — synonym for ll (long long / unsigned long long)
            lengthMod = SentryObjCLenLL;
            fmt++;
        } else if (*fmt == 'z') {
            // z — size_t
            lengthMod = SentryObjCLenZ;
            fmt++;
        } else if (*fmt == 't') {
            // t — ptrdiff_t
            lengthMod = SentryObjCLenT;
            fmt++;
        } else if (*fmt == 'j') {
            // j — intmax_t / uintmax_t
            lengthMod = SentryObjCLenJ;
            fmt++;
        } else if (*fmt == 'L') {
            // L — long double (applies to a, A, e, E, f, F, g, G)
            lengthMod = SentryObjCLenBigL;
            fmt++;
        }

        // Conversion specifier (Table 1) — extract typed arg from va_list
        char spec = *fmt;
        if (spec)
            fmt++;

        id paramValue = nil;

        switch (spec) {

        // %@ — Objective-C object, printed via descriptionWithLocale: or description.
        //       Also works with CFTypeRef objects (CFCopyDescription).
        case '@': {
            id obj = va_arg(args, id);
            paramValue = obj ?: @"(null)";
            break;
        }

        // %d, %i — Signed 32-bit integer (int). With length modifiers:
        //   %ld → long, %lld → long long, %zd → ssize_t, %td → ptrdiff_t, %jd → intmax_t
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
            case SentryObjCLenJ:
                paramValue = @((long long)va_arg(args, intmax_t));
                break;
            default:
                paramValue = @(va_arg(args, int));
                break;
            }
            break;
        }

        // %u — Unsigned 32-bit integer (unsigned int).
        // %x — Unsigned 32-bit integer, hex with lowercase a-f.
        // %X — Unsigned 32-bit integer, hex with uppercase A-F.
        // %o — Unsigned 32-bit integer, octal.
        // With length modifiers:
        //   %lu → unsigned long, %llu → unsigned long long, %zu → size_t,
        //   %tu → ptrdiff_t (unsigned), %ju → uintmax_t
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
            case SentryObjCLenT:
                paramValue = @((unsigned long long)va_arg(args, ptrdiff_t));
                break;
            case SentryObjCLenJ:
                paramValue = @((unsigned long long)va_arg(args, uintmax_t));
                break;
            default:
                paramValue = @(va_arg(args, unsigned int));
                break;
            }
            break;
        }

        // %f — 64-bit floating-point (double).
        // %F — 64-bit floating-point (double), decimal notation.
        // %e — 64-bit floating-point (double), scientific notation with lowercase e.
        // %E — 64-bit floating-point (double), scientific notation with uppercase E.
        // %g — 64-bit floating-point (double), shorter of %e or %f.
        // %G — 64-bit floating-point (double), shorter of %E or %f.
        // %a — 64-bit floating-point (double), hex with lowercase p exponent.
        // %A — 64-bit floating-point (double), hex with uppercase P exponent.
        // With length modifier L: long double (truncated to double for storage).
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

        // %D — Legacy Apple specifier: signed 32-bit integer (int), equivalent to %d.
        case 'D': {
            paramValue = @(va_arg(args, int));
            break;
        }

        // %O — Legacy Apple specifier: unsigned 32-bit integer (unsigned int), octal.
        //       Equivalent to %o.
        // %U — Legacy Apple specifier: unsigned 32-bit integer (unsigned int).
        //       Equivalent to %u.
        case 'O':
        case 'U': {
            paramValue = @(va_arg(args, unsigned int));
            break;
        }

        // %c — 8-bit unsigned character (unsigned char), promoted to int via va_arg.
        case 'c': {
            paramValue = [NSString stringWithFormat:@"%c", (char)va_arg(args, int)];
            break;
        }

        // %C — 16-bit UTF-16 code unit (unichar), promoted to int via va_arg.
        case 'C': {
            paramValue = [NSString stringWithFormat:@"%C", (unichar)va_arg(args, int)];
            break;
        }

        // %S — Null-terminated array of 16-bit UTF-16 code units.
        case 'S': {
            const unichar *s = va_arg(args, const unichar *);
            if (s) {
                NSUInteger len = 0;
                while (s[len] != 0)
                    len++;
                paramValue = [NSString stringWithCharacters:s length:len];
            } else {
                paramValue = @"(null)";
            }
            break;
        }

        // %s — Null-terminated array of 8-bit unsigned characters.
        //       Interpreted in system default encoding by NSString; we attempt
        //       UTF-8 first, then ASCII, to avoid nil on invalid byte sequences.
        case 's': {
            const char *s = va_arg(args, const char *);
            if (s) {
                NSString *str = [NSString stringWithUTF8String:s];
                paramValue = str
                    ?: [NSString stringWithCString:s encoding:NSASCIIStringEncoding]
                    ?: @"(invalid encoding)";
            } else {
                paramValue = @"(null)";
            }
            break;
        }

        // %p — Void pointer (void *), printed in hex with leading 0x and lowercase a-f.
        case 'p': {
            void *ptr = va_arg(args, void *);
            paramValue = [NSString stringWithFormat:@"%p", ptr];
            break;
        }

        default:
            break;
        }

        if (paramValue) {
            [parameters addObject:paramValue];
        }
    }

    NSMutableDictionary<NSString *, id> *attrs = [NSMutableDictionary dictionary];
    if (parameters.count > 0) {
        attrs[@"sentry.message.template"] = format;
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
