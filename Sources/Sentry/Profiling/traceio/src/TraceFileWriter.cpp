// Copyright (c) Specto Inc. All rights reserved.

#include "TraceFileWriter.h"

#include "LZ4.h"
#include "Filesystem.h"
#include "ScopeGuard.h"
#include "external/com_github_lz4_lz4/lib/lz4frame.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <algorithm>
#include <arpa/inet.h>
#include <cstdint>
#include <fstream>
#include <memory>
#include <new>
#include <stdexcept>

namespace specto {

constexpr std::size_t kCompressionInChunkSize = 16 * 1024;
constexpr LZ4F_preferences_t kCompressionPrefs = {{LZ4F_default,
                                                   LZ4F_blockIndependent,
                                                   LZ4F_contentChecksumEnabled,
                                                   LZ4F_frame,
                                                   0ULL,
                                                   0U,
                                                   LZ4F_noBlockChecksum},
                                                  0,
                                                  0u,
                                                  0u,
                                                  {0u, 0u, 0u}};

class TraceFileWriter::Impl {
public:
    Impl(const filesystem::Path &path, bool streamingCompression) :
        outBufCapacity_(0), outBuf_(nullptr) {
        streamingCompression_ = streamingCompression;
        stream_.open(path.string(), std::ios_base::out | std::ios_base::binary);
        if (!stream_) {
            failed_ = true;
            return;
        }
        path_ = path;

        if (streamingCompression) {
            if (!startCompression(stream_)) {
                return;
            }
        }

        const auto version = static_cast<std::uint16_t>(htons(kSpectoFileVersion)); // big endian
        const auto spectoHeaderSize = sizeof(kSpectoFileHeader) - 1; // drop the null terminator
        const auto headerBufSize = spectoHeaderSize + sizeof(version);

        char headerBuf[headerBufSize];
        std::memcpy(headerBuf, kSpectoFileHeader, spectoHeaderSize);
        std::memcpy(headerBuf + spectoHeaderSize, &version, sizeof(version));
        writeBytes(headerBuf, headerBufSize);
    }

    bool writeEntry(const char *buf, std::size_t size) {
        const auto bigEndianSize = static_cast<std::uint32_t>(htonl(size));
        if (!writeBytes(reinterpret_cast<const char *>(&bigEndianSize), sizeof(bigEndianSize))) {
            return false;
        }
        return writeBytes(buf, size);
    }

    bool close() {
        if (stream_.is_open()) {
            if (streamingCompression_) {
                if (!endCompression(stream_)) {
                    return false;
                }
            }
            stream_.close();
            if (!stream_) {
                return false;
            }
            if (!streamingCompression_) {
                return compressEntireFile();
            }
        }
        return true;
    }

    ~Impl() {
        close();
    }

private:
    filesystem::Path path_;
    bool streamingCompression_;
    bool failed_ = false;
    std::ofstream stream_;
    LZ4F_cctx *context_ = nullptr;
    std::size_t outBufCapacity_;
    std::unique_ptr<char[]> outBuf_;

    bool writeBytes(const char *buf, std::size_t size) {
        if (failed_) {
            return false;
        }

        if (streamingCompression_) {
            return writeCompressedBytes(buf, size, stream_);
        } else {
            if (!stream_.write(buf, size)) {
                failed_ = true;
                return false;
            }
            return true;
        }
    }

    bool startCompression(std::ofstream &stream) {
        assert(context_ == nullptr);
        if (failed_) {
            return false;
        }

        const auto err = LZ4F_createCompressionContext(&context_, LZ4F_VERSION);
        if (CHECK_LZ4_ERROR(err)) {
            failed_ = true;
            return false;
        }
        outBufCapacity_ = LZ4F_compressBound(kCompressionInChunkSize, &kCompressionPrefs);
        outBuf_ = std::unique_ptr<char[]>(new (std::nothrow) char[outBufCapacity_]);
        if (outBuf_ == nullptr) {
            failed_ = true;
            return false;
        }

        const auto lz4HeaderSize =
          LZ4F_compressBegin(context_, outBuf_.get(), outBufCapacity_, &kCompressionPrefs);
        if (CHECK_LZ4_ERROR(lz4HeaderSize)) {
            failed_ = true;
            return false;
        }
        if (!stream.write(outBuf_.get(), lz4HeaderSize)) {
            failed_ = true;
            return false;
        }
        return true;
    }

    bool endCompression(std::ofstream &stream) {
        assert(context_ != nullptr);
        if (failed_) {
            return false;
        }

        const auto compressedSize =
          LZ4F_compressEnd(context_, outBuf_.get(), outBufCapacity_, nullptr);
        if (CHECK_LZ4_ERROR(compressedSize)) {
            failed_ = true;
            return false;
        }
        if (!stream.write(outBuf_.get(), compressedSize)) {
            failed_ = true;
            return false;
        }

        const auto err = LZ4F_freeCompressionContext(context_);
        context_ = nullptr;
        if (CHECK_LZ4_ERROR(err)) {
            failed_ = true;
            return false;
        }
        return true;
    }

    bool writeCompressedBytes(const char *buf, std::size_t size, std::ofstream &stream) {
        assert(context_ != nullptr);
        if (failed_) {
            return false;
        }

        while (size > 0) {
            auto chunkSize = std::min(size, kCompressionInChunkSize);
            auto compressedSize = LZ4F_compressUpdate(context_,
                                                      outBuf_.get(),
                                                      outBufCapacity_,
                                                      reinterpret_cast<const void *>(buf),
                                                      chunkSize,
                                                      nullptr);
            if (CHECK_LZ4_ERROR(compressedSize)) {
                failed_ = true;
                return false;
            }
            if (!stream.write(outBuf_.get(), compressedSize)) {
                failed_ = true;
                return false;
            }
            buf += chunkSize;
            size -= chunkSize;
        }
        return true;
    }

    bool compressEntireFile() {
        if (failed_) {
            return false;
        }

        std::ifstream inputStream(path_.string(), std::ios_base::out | std::ios_base::binary);
        if (!inputStream) {
            failed_ = true;
            return false;
        }
        SPECTO_DEFER(inputStream.close());

        const auto tempDirPath = filesystem::createTemporaryDirectory();
        SPECTO_DEFER(filesystem::remove(tempDirPath));
        auto tempPath = tempDirPath;
        tempPath.appendComponent("trace.lz4");
        std::ofstream outputStream(tempPath.string(), std::ios_base::out | std::ios_base::binary);
        if (!outputStream) {
            failed_ = true;
            return false;
        }
        SPECTO_DEFER(outputStream.close());

        if (!startCompression(outputStream)) {
            return false;
        }
        std::unique_ptr<char[]> inputBuf(new (std::nothrow) char[kCompressionInChunkSize]);
        if (inputBuf == nullptr) {
            failed_ = true;
            return false;
        }
        while (inputStream) {
            inputStream.read(inputBuf.get(), kCompressionInChunkSize);
            if (!inputStream.eof() && !inputStream) {
                return false;
            }
            if (!writeCompressedBytes(inputBuf.get(), inputStream.gcount(), outputStream)) {
                return false;
            }
        }
        if (!endCompression(outputStream)) {
            return false;
        }

        return filesystem::rename(tempPath, path_);
    }
};

TraceFileWriter::TraceFileWriter(filesystem::Path path, bool streamingCompression) :
    impl_(spimpl::make_unique_impl<Impl>(std::move(path), streamingCompression)) { }

bool TraceFileWriter::writeEntry(const char *buf, std::size_t size) {
    return impl_->writeEntry(buf, size);
}

bool TraceFileWriter::close() {
    return impl_->close();
}

} // namespace specto
