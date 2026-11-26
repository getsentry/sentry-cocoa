// Adapted from: https://github.com/kstenerud/KSCrash
//
//  SentryCrashString.m
//
//  Created by Karl Stenerud on 2012-09-15.
//
//  Copyright (c) 2012 Karl Stenerud. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall remain in place
// in this source code.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#if !SDK_V10

#    include "SentryCrashString.h"
#    include "SentryInternalCDefines.h"
#    include <stdlib.h>
#    include <string.h>

// Compiler hints for "if" statements
#    define likely_if(x) if (__builtin_expect(x, 1))
#    define unlikely_if(x) if (__builtin_expect(x, 0))

static int
appendChar(char *buffer, size_t bufferLength, size_t *index, char value)
{
    if (*index + 1 >= bufferLength) {
        if (bufferLength > 0) {
            buffer[0] = '\0';
        }
        return -1;
    }

    buffer[(*index)++] = value;
    buffer[*index] = '\0';
    return 0;
}

static int
appendUInt64(char *buffer, size_t bufferLength, size_t *index, uint64_t value)
{
    char reversed[20];
    size_t reversedIndex = 0;
    if (value == 0) {
        reversed[reversedIndex++] = '0';
    } else {
        while (value > 0 && reversedIndex < sizeof(reversed)) {
            reversed[reversedIndex++] = (char)('0' + value % 10);
            value /= 10;
        }
    }

    while (reversedIndex > 0) {
        if (appendChar(buffer, bufferLength, index, reversed[--reversedIndex]) < 0) {
            return -1;
        }
    }
    return 0;
}

int
sentrycrashstring_uint64ToString(char *buffer, size_t bufferLength, uint64_t value)
{
    if (buffer == NULL || bufferLength == 0) {
        return -1;
    }

    buffer[0] = '\0';
    size_t index = 0;
    if (appendUInt64(buffer, bufferLength, &index, value) < 0) {
        return -1;
    }
    return (int)index;
}

int
sentrycrashstring_int64ToString(char *buffer, size_t bufferLength, int64_t value)
{
    if (buffer == NULL || bufferLength == 0) {
        return -1;
    }

    buffer[0] = '\0';
    size_t index = 0;
    uint64_t unsignedValue;
    if (value < 0) {
        if (appendChar(buffer, bufferLength, &index, '-') < 0) {
            return -1;
        }
        unsignedValue = (uint64_t)(-(value + 1)) + 1;
    } else {
        unsignedValue = (uint64_t)value;
    }

    if (appendUInt64(buffer, bufferLength, &index, unsignedValue) < 0) {
        return -1;
    }
    return (int)index;
}

int
sentrycrashstring_addressToString(char *buffer, size_t bufferLength, uint64_t value)
{
    static const char hex[] = "0123456789abcdef";

    if (buffer == NULL || bufferLength == 0) {
        return -1;
    }

    buffer[0] = '\0';
    size_t index = 0;
    if (appendChar(buffer, bufferLength, &index, '0') < 0
        || appendChar(buffer, bufferLength, &index, 'x') < 0) {
        return -1;
    }

    char reversed[2 * sizeof(uint64_t)];
    size_t reversedIndex = 0;
    if (value == 0) {
        reversed[reversedIndex++] = '0';
    } else {
        while (value > 0 && reversedIndex < sizeof(reversed)) {
            reversed[reversedIndex++] = hex[value & 0x0f];
            value >>= 4;
        }
    }

    while (reversedIndex > 0) {
        if (appendChar(buffer, bufferLength, &index, reversed[--reversedIndex]) < 0) {
            return -1;
        }
    }
    return (int)index;
}

int
sentrycrashstring_doubleToString(char *buffer, size_t bufferLength, double value)
{
    if (buffer == NULL || bufferLength == 0) {
        return -1;
    }

    buffer[0] = '\0';
    size_t index = 0;
    if (value == 0.0) {
        if (appendChar(buffer, bufferLength, &index, '0') < 0) {
            return -1;
        }
        return (int)index;
    }

    double positiveValue = value;
    if (value < 0.0) {
        if (appendChar(buffer, bufferLength, &index, '-') < 0) {
            return -1;
        }
        positiveValue = -value;
    }

    int exponent = 0;
    double normalized = positiveValue;
    while (normalized >= 10.0) {
        normalized /= 10.0;
        exponent++;
    }
    while (normalized < 1.0) {
        normalized *= 10.0;
        exponent--;
    }

    uint64_t scaled = (uint64_t)(normalized * 100000.0 + 0.5);
    if (scaled >= 1000000) {
        scaled = 100000;
        exponent++;
    }

    char digits[6];
    for (int i = 5; i >= 0; i--) {
        digits[i] = (char)('0' + scaled % 10);
        scaled /= 10;
    }

    if (exponent < -4 || exponent >= 6) {
        if (appendChar(buffer, bufferLength, &index, digits[0]) < 0) {
            return -1;
        }

        int lastSignificant = 5;
        while (lastSignificant > 0 && digits[lastSignificant] == '0') {
            lastSignificant--;
        }
        if (lastSignificant > 0) {
            if (appendChar(buffer, bufferLength, &index, '.') < 0) {
                return -1;
            }
            for (int i = 1; i <= lastSignificant; i++) {
                if (appendChar(buffer, bufferLength, &index, digits[i]) < 0) {
                    return -1;
                }
            }
        }

        if (appendChar(buffer, bufferLength, &index, 'e') < 0) {
            return -1;
        }
        if (exponent < 0) {
            if (appendChar(buffer, bufferLength, &index, '-') < 0) {
                return -1;
            }
            exponent = -exponent;
        }
        if (appendUInt64(buffer, bufferLength, &index, (uint64_t)exponent) < 0) {
            return -1;
        }
        return (int)index;
    }

    const int decimalPosition = exponent + 1;
    if (decimalPosition <= 0) {
        if (appendChar(buffer, bufferLength, &index, '0') < 0
            || appendChar(buffer, bufferLength, &index, '.') < 0) {
            return -1;
        }
        for (int i = 0; i < -decimalPosition; i++) {
            if (appendChar(buffer, bufferLength, &index, '0') < 0) {
                return -1;
            }
        }
        for (int i = 0; i < 6; i++) {
            if (appendChar(buffer, bufferLength, &index, digits[i]) < 0) {
                return -1;
            }
        }
    } else {
        for (int i = 0; i < decimalPosition; i++) {
            char digit = i < 6 ? digits[i] : '0';
            if (appendChar(buffer, bufferLength, &index, digit) < 0) {
                return -1;
            }
        }
        if (decimalPosition < 6) {
            if (appendChar(buffer, bufferLength, &index, '.') < 0) {
                return -1;
            }
            for (int i = decimalPosition; i < 6; i++) {
                if (appendChar(buffer, bufferLength, &index, digits[i]) < 0) {
                    return -1;
                }
            }
        }
    }

    if (decimalPosition < 6) {
        while (index > 0 && buffer[index - 1] == '0') {
            buffer[--index] = '\0';
        }
        if (index > 0 && buffer[index - 1] == '.') {
            buffer[--index] = '\0';
        }
    }

    return (int)index;
}

static const int g_printableControlChars[0x20] = {
    // Only tab, CR, and LF are considered printable
    // 1  2  3  4  5  6  7  8  9  a  b  c  d  e  f
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    1,
    1,
    0,
    0,
    1,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
};

bool
sentrycrashstring_isNullTerminatedUTF8String(const void *memory, int minLength, int maxLength)
{
    const unsigned char *ptr = memory;
    const unsigned char *const end = ptr + maxLength;

    for (; ptr < end; ptr++) {
        unsigned char ch = *ptr;
        unlikely_if(ch == 0) { return (ptr - (const unsigned char *)memory) >= minLength; }
        unlikely_if(ch & 0x80)
        {
            // Enforce RFC 3629 UTF-8: reject overlong encodings, UTF-16 surrogates
            // (U+D800..U+DFFF), and code points above U+10FFFF.
            int continuationBytes;
            unsigned char firstContMin = 0x80;
            unsigned char firstContMax = 0xbf;
            if (ch >= 0xc2 && ch <= 0xdf) {
                continuationBytes = 1;
            } else if (ch >= 0xe0 && ch <= 0xef) {
                continuationBytes = 2;
                if (ch == 0xe0) {
                    firstContMin = 0xa0;
                } else if (ch == 0xed) {
                    firstContMax = 0x9f;
                }
            } else if (ch >= 0xf0 && ch <= 0xf4) {
                continuationBytes = 3;
                if (ch == 0xf0) {
                    firstContMin = 0x90;
                } else if (ch == 0xf4) {
                    firstContMax = 0x8f;
                }
            } else {
                return false;
            }

            unlikely_if(ptr + continuationBytes >= end) { return false; }
            ptr++;
            unlikely_if(*ptr < firstContMin || *ptr > firstContMax) { return false; }
            for (int i = 1; i < continuationBytes; i++) {
                ptr++;
                unlikely_if((*ptr & 0xc0) != 0x80) { return false; }
            }
        }
        else unlikely_if(ch < 0x20 && !g_printableControlChars[ch])
        {
            return false;
        }
    }
    return false;
}

void
sentrycrashstring_trimTrailingIncompleteUTF8(char *buffer, int length)
{
    if (buffer == NULL || length <= 0) {
        return;
    }

    // Walk back over any trailing UTF-8 continuation bytes (10xxxxxx).
    int i = length - 1;
    while (i > 0 && ((unsigned char)buffer[i] & 0xc0) == 0x80) {
        i--;
    }

    unsigned char lead = (unsigned char)buffer[i];
    if ((lead & 0x80) == 0) {
        return;
    }

    int expectedLength = 0;
    if (lead >= 0xc2 && lead <= 0xdf) {
        expectedLength = 2;
    } else if (lead >= 0xe0 && lead <= 0xef) {
        expectedLength = 3;
    } else if (lead >= 0xf0 && lead <= 0xf4) {
        expectedLength = 4;
    }

    if (expectedLength == 0 || (length - i) < expectedLength) {
        buffer[i] = '\0';
    }
}

#    define INV 0xff

/** Lookup table for converting hex values to integers.
 * INV (0x11111) is used to mark invalid characters so that any attempted
 * invalid nybble conversion is always > 0xffff.
 */
static const unsigned int g_hexConversion[] = {
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0x0,
    0x1,
    0x2,
    0x3,
    0x4,
    0x5,
    0x6,
    0x7,
    0x8,
    0x9,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0xa,
    0xb,
    0xc,
    0xd,
    0xe,
    0xf,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    0xa,
    0xb,
    0xc,
    0xd,
    0xe,
    0xf,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
    INV,
};

bool
sentrycrashstring_extractHexValue(const char *string, int stringLength, uint64_t *const result)
{
    if (stringLength > 0) {
        const unsigned char *current = (const unsigned char *)string;
        const unsigned char *const end = current + stringLength;
        for (;;) {
            current = (const unsigned char *)strnstr(
                (const char *)current, "0x", (unsigned)(end - current));
            unlikely_if(!current) { return false; }
            current += 2;

            // Must have at least one valid digit after "0x".
            unlikely_if(g_hexConversion[*current] == INV) { continue; }

            uint64_t accum = 0;
            unsigned int nybble = 0;
            while (current < end) {
                nybble = g_hexConversion[*current++];
                unlikely_if(nybble == INV) { break; }
                accum <<= 4;
                accum += nybble;
            }
            *result = accum;
            return true;
        }
    }
    return false;
}

#endif // !SDK_V10
