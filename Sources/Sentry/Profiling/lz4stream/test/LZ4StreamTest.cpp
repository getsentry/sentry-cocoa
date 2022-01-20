// Copyright (c) Specto Inc. All rights reserved.

// Copyright (c) 2015, Kasper Laudrup <laudrup@stacktrace.dk>
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
// 1. Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//
// 2. Redistributions in binary form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// 3. Neither the name of the copyright holder nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// Original source: https://github.com/laudrup/lz4_stream
//
// Tests were ported from Catch to gtest.
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include "gtest/gtest.h"
#pragma clang diagnostic pop

#include "cpp/lz4stream/src/LZ4Stream.h"

#include <sstream>
#include <string>

namespace {
constexpr auto test_string = "Three Rings for the Elven-kings under the sky,\n"
                             "Seven for the Dwarf-lords in their halls of stone,\n"
                             "Nine for Mortal Men doomed to die,\n"
                             "One for the Dark Lord on his dark throne\n"
                             "In the Land of Mordor where the Shadows lie.\n"
                             "One Ring to rule them all, One Ring to find them,\n"
                             "One Ring to bring them all, and in the darkness bind them,\n"
                             "In the Land of Mordor where the Shadows lie.\n";
}

class LZ4StreamTest : public ::testing::Test {
protected:
    LZ4StreamTest() : lz4_out_stream(compressed_stream), lz4_in_stream(compressed_stream) { }

    std::stringstream compressed_stream;
    lz4_stream::ostream lz4_out_stream;
    lz4_stream::istream lz4_in_stream;
};

TEST_F(LZ4StreamTest, TestDefaultCompressionDecompression) {
    lz4_out_stream << test_string;
    lz4_out_stream.close();

    EXPECT_EQ(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}), test_string);
}

TEST_F(LZ4StreamTest, TestEmptyData) {
    lz4_out_stream.close();

    EXPECT_TRUE(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}).empty());
}

TEST_F(LZ4StreamTest, TestAllZeroes) {
    lz4_out_stream << std::string(1024, '\0');
    lz4_out_stream.close();

    EXPECT_EQ(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}),
              std::string(1024, '\0'));
}

TEST_F(LZ4StreamTest, TestSmallOutputBuffer) {
    std::stringstream compressed_stream;
    lz4_stream::basic_ostream<8> lz4_out_stream(compressed_stream);
    lz4_stream::istream lz4_in_stream(compressed_stream);
    lz4_out_stream << test_string;
    lz4_out_stream.close();

    EXPECT_EQ(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}), test_string);
}

TEST_F(LZ4StreamTest, TestSmallInputBuffer) {
    lz4_stream::basic_istream<8, 8> lz4_in_stream(compressed_stream);
    lz4_out_stream << test_string;
    lz4_out_stream.close();

    EXPECT_EQ(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}), test_string);
}

TEST_F(LZ4StreamTest, TestSmallInputAndOutputBuffer) {
    std::stringstream compressed_stream;
    lz4_stream::basic_istream<8, 8> lz4_in_stream(compressed_stream);
    lz4_stream::basic_ostream<8> lz4_out_stream(compressed_stream);
    lz4_out_stream << test_string;
    lz4_out_stream.close();

    EXPECT_EQ(std::string(std::istreambuf_iterator<char>(lz4_in_stream), {}), test_string);
}
