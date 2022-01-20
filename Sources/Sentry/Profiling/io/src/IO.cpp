// Copyright (c) Specto Inc. All rights reserved.

// Adapted from Firebase Crashlytics; the original license content follows, in
// compliance with that license:

// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#include "IO.h"

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <unistd.h>

namespace specto::io::async_safe {

namespace {

/** uint64_t should only have max 19 chars in base 10, and less in base 16 */
constexpr std::size_t uint64StringBufferLength_ = 21;

constexpr auto maxWriteAttempts_ = 50;

bool writeWithRetries(int fd, const void* buffer, std::size_t length) {
    for (auto count = 0; length > 0 && count < maxWriteAttempts_; ++count) {
        // try to write all that is left
        const auto ret = write(fd, buffer, length);

        if (length > SIZE_MAX) {
            // if this happens we can't convert it to a signed version due to overflow
            return false;
        }
        const auto signedLength = static_cast<ssize_t>(length);

        if (ret >= 0 && ret == signedLength) {
            return true;
        }

        // Write was unsuccessful (out of space, etc)
        if (ret < 0) {
            return false;
        }

        // We wrote more bytes than we expected, abort
        if (ret > signedLength) {
            return false;
        }

        // wrote a portion of the data, adjust and keep trying
        if (ret > 0) {
            length -= ret;
            buffer = (char*)buffer + ret;
            continue;
        }

        // return value is <= 0, which is an error
        break;
    }

    return false;
}

short prepareUInt64(char* buffer, uint64_t number, bool hex) {
    const auto base = hex ? 16 : 10;

    // zero it out, which will add a terminator
    std::memset(buffer, 0, uint64StringBufferLength_);

    // Set current index.
    auto i = uint64StringBufferLength_ - 1;

    // Loop through filling in the chars from the end.
    do {
        char value = number % base + '0';
        if (value > '9') {
            value += 'a' - '9' - 1;
        }

        buffer[--i] = value;
    } while ((number /= base) > 0 && i > 0);

    // returns index pointing to the beginning of the string.
    return i;
}

void writeUInt64(int fd, uint64_t number, bool hex) {
    char buffer[uint64StringBufferLength_];
    const auto i = prepareUInt64(buffer, number, hex);
    const auto beginning = &buffer[i]; // Write from a pointer to the begining of the string.
    writeWithRetries(fd, beginning, strlen(beginning));
}

void writeInt64(int fd, int64_t number) {
    if (number < 0) {
        writeWithRetries(fd, "-", 1);
        number *= -1; // make it positive
    }

    writeUInt64(fd, number, false);
}

} // namespace

void safeWrite(const int fd, const char* format, va_list args) {
#if !NDEBUG && 0
    // It's nice to use printf here, so all the formatting works. However, its possible to hit a
    // deadlock if you call vfprintf in a crash handler. So, this code is handy to keep, just in
    // case, if there's a really tough thing to debug.
    FILE* file = fopen(path, "a+");
    vfprintf(file, format, args);
    fclose(file);
#else
    const auto formatLength = strlen(format);
    for (size_t idx = 0; idx < formatLength; ++idx) {
        if (format[idx] != '%') {
            write(fd, &format[idx], 1);
            continue;
        }

        idx++; // move to the format char
        switch (format[idx]) {
            case 'd': {
                const auto value = va_arg(args, int);
                writeInt64(fd, value);
            } break;
            case 'u': {
                const auto value = va_arg(args, uint32_t);
                writeUInt64(fd, value, false);
            } break;
            case 'p': {
                const auto value = va_arg(args, uintptr_t);
                write(fd, "0x", 2);
                writeUInt64(fd, value, true);
            } break;
            case 's': {
                auto string = va_arg(args, const char*);
                if (!string) {
                    string = "(null)";
                }

                write(fd, string, strlen(string));
            } break;
            case 'x': {
                const auto value = va_arg(args, unsigned int);
                writeUInt64(fd, value, true);
            } break;
            default:
                // unhandled, back up to write out the percent + the format char
                write(fd, &format[idx - 1], 2);
                break;
        }
    }
#endif
}

} // namespace specto::io::async_safe
