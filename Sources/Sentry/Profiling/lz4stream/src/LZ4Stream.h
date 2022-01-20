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
// This implementation is based on the fork at
// https://github.com/nh2/lz4_stream/tree/fix-context-leak-add-exceptions with minor modifications.
// The fork was submitted as a PR to the upstream repository but has not been merged:
// https://github.com/laudrup/lz4_stream/pull/6
#ifndef LZ4_STREAM
#define LZ4_STREAM

// LZ4 Headers
#include "external/com_github_lz4_lz4/lib/lz4frame.h"

// Standard headers
#include <array>
#include <cassert>
#include <functional>
#include <iostream>
#include <memory>
#include <streambuf>
#include <vector>

namespace lz4_stream {
constexpr LZ4F_preferences_t kCompressionPrefs = {
  {LZ4F_max256KB,
   LZ4F_blockIndependent,
   LZ4F_noContentChecksum,
   LZ4F_frame,
   0 /* unknown content size */,
   0 /* no dictID */,
   LZ4F_noBlockChecksum},
  0, /* compression level; 0 == default */
  0, /* autoflush */
  0, /* favor decompression speed */
  {0, 0, 0}, /* reserved, must be set to 0 */
};

/**
 * @brief An output stream that will LZ4 compress the input data.
 *
 * An output stream that will wrap another output stream and LZ4
 * compress its input data to that stream.
 *
 * It will enable exceptions on the output stream using
 *
 * @code{.cpp}
 * sink.exceptions(std::ostream::badbit);
 * @endcode
 *
 * to ensure that write errors do not go unnoticed.
 *
 * Once an exception has been raised, you are not allowed to use
 * the stream further (this is not checked), because the library
 * currently does not ensure to maintain a correct internal LZ4
 * state when it happens.
 *
 */
template<size_t SrcBufSize = (4096 * 4)>
class basic_ostream : public std::ostream {
public:
    /**
     * @brief Constructs an LZ4 compression output stream
     *
     * @param sink The stream to write compressed data to
     */
    basic_ostream(std::ostream& sink) :
        std::ostream(new output_buffer(sink)), buffer_(dynamic_cast<output_buffer*>(rdbuf())) {
        assert(buffer_);
    }

    /**
     * @brief Destroys the LZ4 output stream. Calls close() if not already called.
     */
    ~basic_ostream() {
        close();
        delete buffer_;
    }

    /**
     * @brief Flushes and writes LZ4 footer data to the LZ4 output stream.
     *
     * After calling this function no more data should be written to the stream.
     */
    void close() {
        buffer_->close();
    }

private:
    /**
     * @brief RAII version of `LZ4F_compressionContext_t`.
     */
    struct compression_context {
        LZ4F_compressionContext_t ctx;

        compression_context() {
            size_t ret = LZ4F_createCompressionContext(&ctx, LZ4F_VERSION);
            if (LZ4F_isError(ret) != 0) {
                throw std::runtime_error(std::string("Failed to create LZ4 compression context: ")
                                         + LZ4F_getErrorName(ret));
            }
        }

        ~compression_context() {
            LZ4F_freeCompressionContext(ctx);
        }
    };

    class output_buffer : public std::streambuf {
    public:
        output_buffer(const output_buffer&) = delete;
        output_buffer& operator=(const output_buffer&) = delete;

        output_buffer(std::ostream& sink) :
            sink_(sink),
            // TODO: No need to recalculate the dest_buf_ size on each construction
            dest_buf_(LZ4F_compressBound(src_buf_.size(), &kCompressionPrefs)), closed_(false) {
            char* base = &src_buf_.front();
            setp(base, base + src_buf_.size() - 1);

            sink.exceptions(std::ostream::badbit);

            write_header();
        }

        ~output_buffer() {
            close();
        }

        void close() {
            if (closed_) {
                return;
            }
            sync();
            write_footer();
            closed_ = true;
        }

    private:
        int_type overflow(int_type ch) override {
            assert(std::less_equal<char*>()(pptr(), epptr()));

            *pptr() = static_cast<basic_ostream::char_type>(ch);
            pbump(1);
            compress_and_write();

            return ch;
        }

        int_type sync() override {
            compress_and_write();
            return 0;
        }

        void throw_if_closed() {
            if (closed_) {
                throw std::runtime_error(std::string("lz4_stream::basic_ostream used after close"));
            }
        }

        void compress_and_write() {
            throw_if_closed();
            int orig_size = static_cast<int>(pptr() - pbase());
            pbump(-orig_size);
            size_t ret = LZ4F_compressUpdate(
              context_.ctx, &dest_buf_.front(), dest_buf_.capacity(), pbase(), orig_size, nullptr);
            if (LZ4F_isError(ret) != 0) {
                throw std::runtime_error(std::string("LZ4 compression failed: ")
                                         + LZ4F_getErrorName(ret));
            }
            sink_.write(&dest_buf_.front(), ret);
        }

        void write_header() {
            throw_if_closed();
            size_t ret = LZ4F_compressBegin(
              context_.ctx, &dest_buf_.front(), dest_buf_.capacity(), &kCompressionPrefs);
            if (LZ4F_isError(ret) != 0) {
                throw std::runtime_error(std::string("Failed to start LZ4 compression: ")
                                         + LZ4F_getErrorName(ret));
            }
            sink_.write(&dest_buf_.front(), ret);
        }

        void write_footer() {
            throw_if_closed();
            size_t ret =
              LZ4F_compressEnd(context_.ctx, &dest_buf_.front(), dest_buf_.capacity(), nullptr);
            if (LZ4F_isError(ret) != 0) {
                throw std::runtime_error(std::string("Failed to end LZ4 compression: ")
                                         + LZ4F_getErrorName(ret));
            }
            sink_.write(&dest_buf_.front(), ret);
        }

        std::ostream& sink_;
        std::array<char, SrcBufSize> src_buf_;
        std::vector<char> dest_buf_;
        compression_context context_;
        bool closed_;
    };

    output_buffer* buffer_;
};

/**
 * @brief An input stream that will LZ4 decompress output data.
 *
 * An input stream that will wrap another input stream and LZ4
 * decompress its output data to that stream.
 *
 * It will enable exceptions on the input stream using
 *
 * @code{.cpp}
 * source.exceptions(std::istream::badbit);
 * @endcode
 *
 * to ensure that read errors do not go unnoticed.
 *
 * Once an exception has been raised, you are not allowed to use
 * the stream further (this is not checked), because the library
 * currently does not ensure to maintain a correct internal LZ4
 * state when it happens.
 */
template<size_t SrcBufSize = (4096 * 4), size_t DestBufSize = (4096 * 4)>
class basic_istream : public std::istream {
public:
    /**
     * @brief Constructs an LZ4 decompression input stream
     *
     * @param source The stream to read LZ4 compressed data from
     */
    basic_istream(std::istream& source) :
        std::istream(new input_buffer(source)), buffer_(dynamic_cast<input_buffer*>(rdbuf())) {
        assert(buffer_);
    }

    /**
     * @brief Destroys the LZ4 output stream.
     */
    ~basic_istream() {
        delete buffer_;
    }

private:
    /**
     * @brief RAII version of `LZ4F_decompressionContext_t`.
     */
    struct decompression_context {
        LZ4F_decompressionContext_t ctx;

        decompression_context() {
            size_t ret = LZ4F_createDecompressionContext(&ctx, LZ4F_VERSION);
            if (LZ4F_isError(ret) != 0) {
                throw std::runtime_error(std::string("Failed to create LZ4 decompression context: ")
                                         + LZ4F_getErrorName(ret));
            }
        }

        ~decompression_context() {
            LZ4F_freeDecompressionContext(ctx);
        }
    };

    class input_buffer : public std::streambuf {
    public:
        input_buffer(std::istream& source) : source_(source), offset_(0), src_buf_size_(0) {
            setg(&src_buf_.front(), &src_buf_.front(), &src_buf_.front());

            source.exceptions(std::istream::badbit);
        }

        int_type underflow() override {
            size_t written_size = 0;
            while (written_size == 0) {
                if (offset_ == src_buf_size_) {
                    source_.read(&src_buf_.front(), src_buf_.size());
                    src_buf_size_ = static_cast<size_t>(source_.gcount());
                    offset_ = 0;
                }

                if (src_buf_size_ == 0) {
                    return traits_type::eof();
                }

                size_t src_size = src_buf_size_ - offset_;
                size_t dest_size = dest_buf_.size();
                size_t ret = LZ4F_decompress(context_.ctx,
                                             &dest_buf_.front(),
                                             &dest_size,
                                             &src_buf_.front() + offset_,
                                             &src_size,
                                             nullptr);
                if (LZ4F_isError(ret) != 0) {
                    throw std::runtime_error(std::string("LZ4 decompression failed: ")
                                             + LZ4F_getErrorName(ret));
                }
                written_size = dest_size;
                offset_ += src_size;
            }
            setg(&dest_buf_.front(), &dest_buf_.front(), &dest_buf_.front() + written_size);
            return traits_type::to_int_type(*gptr());
        }

        input_buffer(const input_buffer&) = delete;
        input_buffer& operator=(const input_buffer&) = delete;

    private:
        std::istream& source_;
        std::array<char, SrcBufSize> src_buf_;
        std::array<char, DestBufSize> dest_buf_;
        size_t offset_;
        size_t src_buf_size_;
        decompression_context context_;
    };

    input_buffer* buffer_;
};

using ostream = basic_ostream<>;
using istream = basic_istream<>;

} // namespace lz4_stream
#endif // LZ4_STREAM
