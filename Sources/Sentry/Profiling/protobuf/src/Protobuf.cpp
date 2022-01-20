// Copyright (c) Specto Inc. All rights reserved.

#include "Protobuf.h"

#include "cpp/time/src/Time.h"

namespace specto::protobuf {

proto::Entry makeEntry(proto::Entry_Type type,
                       std::string groupID,
                       time::Type timestampNs,
                       thread::TIDType tid) noexcept {
    proto::Entry entry;
    entry.set_elapsed_relative_to_start_date_ns(timestampNs);
    entry.set_tid(tid);
    entry.set_type(type);
    entry.set_group_id(std::move(groupID));
    return entry;
}

} // namespace specto::protobuf
