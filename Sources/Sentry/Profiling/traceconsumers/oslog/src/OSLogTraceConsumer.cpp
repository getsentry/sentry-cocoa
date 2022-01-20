// Copyright (c) Specto Inc. All rights reserved.

#include "OSLogTraceConsumer.h"

#if !defined(NDEBUG)
//#include "spectoproto./entry/entry_generated.pb.h"

#include <google/protobuf/util/json_util.h>
#include <mutex>
#include <os/log.h>
#include <string>
#endif

namespace specto {

OSLogTraceConsumer::OSLogTraceConsumer() = default;

void OSLogTraceConsumer::start(__unused TraceID id) { }
void OSLogTraceConsumer::end(__unused bool successful) { }

#if !defined(NDEBUG)

constexpr const char *const kOSLogSubsystem = "dev.specto.Specto";

void OSLogTraceConsumer::receiveEntryBuffer(std::shared_ptr<char> buf, std::size_t size) {
    static google::protobuf::util::JsonPrintOptions printOptions;
    std::once_flag printOptionsOnceFlag;
    std::call_once(printOptionsOnceFlag, []() {
        printOptions.add_whitespace = true;
        printOptions.always_print_primitive_fields = true;
        printOptions.preserve_proto_field_names = true;
    });

    proto::Entry entry;
    entry.ParseFromArray(buf.get(), static_cast<int>(size));

    std::string json;
    google::protobuf::util::MessageToJsonString(entry, &json, printOptions);

    const auto log = os_log_create(kOSLogSubsystem, proto::Entry_Type_Name(entry.type()).c_str());
    os_log_with_type(log, OS_LOG_TYPE_DEFAULT, "%s", json.c_str());
}
#else
void OSLogTraceConsumer::receiveEntryBuffer(__unused std::shared_ptr<char> buf,
                                            __unused std::size_t size) { }
#endif

} // namespace specto
