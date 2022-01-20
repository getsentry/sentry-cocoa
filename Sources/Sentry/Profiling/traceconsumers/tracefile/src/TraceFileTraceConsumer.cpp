// Copyright (c) Specto Inc. All rights reserved.

#include "TraceFileTraceConsumer.h"

#include "cpp/exception/src/Exception.h"
#include "cpp/log/src/Log.h"
#include "cpp/traceio/src/TraceFileWriter.h"
#include "cpp/util/src/ThreadPool.h"
#include "spectoproto/entry/entry_generated.pb.h"

#include <cassert>
#include <functional>
#include <memory>
#include <mutex>

#if !defined(NDEBUG) && defined(__APPLE__)
#include <execinfo.h>
#endif

namespace specto {
namespace {

class TraceFileIOContext {
public:
    explicit TraceFileIOContext(std::shared_ptr<TraceFileManager> fileManager) :
        fileManager_(std::move(fileManager)) { }

    void start(TraceID id) {
        path_ = fileManager_->newTracePath(std::move(id));
        writer_ = std::make_shared<TraceFileWriter>(path_);
    }

    void end() {
        assert(writer_ != nullptr);
        if (writer_ == nullptr) {
            SPECTO_LOG_ERROR("Called end() more than once");
            return;
        }
        if (!writer_->close()) {
            SPECTO_LOG_ERROR("Failed to close writer for {}", path_.string());
        }
        fileManager_->markTraceCompleted(path_);

        path_ = filesystem::Path {};
        writer_ = nullptr;
    }

    void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
        assert(writer_ != nullptr);
        assert(buf != nullptr);
        if (buf == nullptr) {
            SPECTO_LOG_ERROR("Received null entry buffer");
            return;
        }
        if (writer_ == nullptr) {
            SPECTO_LOG_ERROR("receiveEntryBuffer was called after end");
            return;
        }
        // On iOS debug builds, we extract symbol information directly on-device
        // since debug information is present in the binary; this is useful for debugging.
#if !defined(NDEBUG) && defined(__APPLE__)
        proto::Entry entry;
        entry.ParseFromArray(buf.get(), static_cast<int>(size));
        if (entry.type() == proto::Entry_Type_BACKTRACE) {
            const auto addressesSize = entry.backtrace().addresses_size();
            const auto symbols = backtrace_symbols(
              reinterpret_cast<void *const *>(entry.backtrace().addresses().data()), addressesSize);
            for (int i = 0; i < addressesSize; i++) {
                entry.mutable_backtrace()->add_symbols(symbols[i]);
            }
            free(symbols);
        }
#endif
        if (failed_) {
            return;
        }
        if (!writer_->writeEntry(buf.get(), size)) {
            SPECTO_LOG_ERROR("Failed to write entry data for {}", path_.string());
            failed_ = true;
        }
    }

private:
    std::shared_ptr<TraceFileManager> fileManager_;
    filesystem::Path path_;
    std::shared_ptr<TraceFileWriter> writer_;
    bool failed_ = false;
};
} // namespace

class TraceFileTraceConsumer::Impl {
public:
    Impl(std::shared_ptr<TraceFileManager> fileManager, bool synchronous) :
        pool_(1 /* 1 thread */), ctx_(std::make_shared<TraceFileIOContext>(std::move(fileManager))),
        synchronous_(synchronous) { }

    void start(TraceID id) {
        runTask([id = std::move(id)](auto ctx) { ctx->start(std::move(id)); });
    }

    void end() {
        runTask([](auto ctx) { ctx->end(); });
    }

    void receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
        runTask([buf = std::move(buf), size](auto ctx) {
            ctx->receiveEntryBuffer(std::move(buf), size);
        });
    }

private:
    ThreadPool pool_;
    std::shared_ptr<TraceFileIOContext> ctx_;
    bool synchronous_;
    std::mutex lock_;

    void runTask(std::function<void(std::shared_ptr<TraceFileIOContext>)> task) {
        assert(task);
        if (!task) {
            SPECTO_LOG_ERROR("Attempted to execute null task");
            return;
        }
        if (synchronous_) {
            std::lock_guard<std::mutex> l(lock_);
            SPECTO_HANDLE_CPP_EXCEPTION(task(ctx_));
        } else {
            pool_.enqueue([task = std::move(task), ctx = ctx_] {
                SPECTO_HANDLE_CPP_EXCEPTION(task(std::move(ctx)));
            });
        }
    }
};

TraceFileTraceConsumer::TraceFileTraceConsumer(std::shared_ptr<TraceFileManager> fileManager,
                                               bool synchronous) :
    impl_(spimpl::make_unique_impl<Impl>(std::move(fileManager), synchronous)) { }

void TraceFileTraceConsumer::start(TraceID id) {
    impl_->start(std::move(id));
}

void TraceFileTraceConsumer::end(__unused bool successful) {
    impl_->end();
}

void TraceFileTraceConsumer::receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
    impl_->receiveEntryBuffer(std::move(buf), size);
}

} // namespace specto
