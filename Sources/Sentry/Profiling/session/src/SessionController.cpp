// Copyright (c) Specto Inc. All rights reserved.

#include "SessionController.h"

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/log/src/Log.h"
#include "cpp/protobuf/src/Protobuf.h"
#include "cpp/thread/src/Thread.h"
#include "cpp/trace/src/TraceConsumer.h"
#include "cpp/util/src/ScopeGuard.h"
#include "spectoproto/session/session_metadata_generated.pb.h"

#include <cassert>
#include <fstream>
#include <string>

namespace specto {

SessionController::SessionController() : id_(TraceID::empty), referenceUptimeNs_(0) { }

TraceID SessionController::currentSessionID() const {
    std::lock_guard<std::mutex> l(lock_);
    return id_;
}

void SessionController::startSession(std::shared_ptr<TraceConsumer> consumer) {
    assert(consumer != nullptr);

    std::lock_guard<std::mutex> l(lock_);
    if (!id_.isEmpty()) {
        SPECTO_LOG_WARN("Called SessionController::startSession while a session was active, ending "
                        "the previous session");
        consumer_->end(true);
    }

    referenceUptimeNs_ = time::getUptimeNs();
    id_ = TraceID {};
    SPECTO_LOG_INFO("Starting session {}", id_.uuid());

    consumer_ = std::move(consumer);
    consumer_->start(id_);

    auto entry = protobuf::makeEntry(proto::Entry_Type_SESSION_START, id_.uuid());
    entry.mutable_session_metadata()->set_start_date_sec(time::getSecondsSinceEpoch().count());
    _log(std::move(entry));
}

void SessionController::endSession() {
    std::lock_guard<std::mutex> l(lock_);
    if (id_.isEmpty()) {
        SPECTO_LOG_WARN("Called SessionController::endSession without an active session");
        return;
    }
    SPECTO_LOG_INFO("Ending session {}", id_.uuid());

    auto entry = protobuf::makeEntry(proto::Entry_Type_SESSION_END, id_.uuid());
    _log(std::move(entry));
    id_ = TraceID::empty;
    referenceUptimeNs_ = 0;
    consumer_->end(true);
    consumer_ = nullptr;
}

void SessionController::log(proto::Entry entry) const {
    std::lock_guard<std::mutex> l(lock_);
    _log(std::move(entry));
}

void SessionController::unsafeLogBytes(std::shared_ptr<char> buf, std::size_t size) const {
    std::lock_guard<std::mutex> l(lock_);
    _unsafeLogBytes(std::move(buf), size);
}

time::Type SessionController::referenceUptimeNs() const {
    std::lock_guard<std::mutex> l(lock_);
    return referenceUptimeNs_;
}

void SessionController::_log(proto::Entry entry) const {
    entry.set_elapsed_relative_to_start_date_ns(time::getDurationNs(referenceUptimeNs_).count());
    const auto size = entry.ByteSizeLong();
    std::shared_ptr<char> buf(new char[size], std::default_delete<char[]>());
    entry.SerializeToArray(buf.get(), size);
    _unsafeLogBytes(std::move(buf), size);
}

void SessionController::_unsafeLogBytes(std::shared_ptr<char> buf, std::size_t size) const {
    if (consumer_ != nullptr) {
        consumer_->receiveEntryBuffer(std::move(buf), size);
    } else {
        SPECTO_LOG_WARN(
          "Called SessionController::unsafeLogBytes while there was no active session");
    }
}

} // namespace specto
