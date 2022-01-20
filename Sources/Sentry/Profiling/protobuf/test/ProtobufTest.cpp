// Copyright (c) Specto Inc. All rights reserved.

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wextra"
#include <gtest/gtest.h>
#pragma clang diagnostic pop

#include "cpp/filesystem/src/Filesystem.h"
#include "cpp/filesystem/src/Path.h"
#include "cpp/protobuf/src/Protobuf.h"

// global config proto type
#include "spectoproto/global/global_generated.pb.h"

// the entry proto type, with all of its oneof types
#include "spectoproto/androidtrace/androidtrace_generated.pb.h"
#include "spectoproto/annotation/annotation_generated.pb.h"
#include "spectoproto/appinfo/appinfo_generated.pb.h"
#include "spectoproto/backtrace/backtrace_generated.pb.h"
#include "spectoproto/cpu/cpu_generated.pb.h"
#include "spectoproto/device/device_generated.pb.h"
#include "spectoproto/entry/entry_generated.pb.h"
#include "spectoproto/error/error_generated.pb.h"
#include "spectoproto/memorymappedimages/memorymappedimages_generated.pb.h"
#include "spectoproto/memorypressure/memorypressure_generated.pb.h"
#include "spectoproto/networking/networking_generated.pb.h"
#include "spectoproto/ringbuffer/ringbuffer_generated.pb.h"
#include "spectoproto/session/session_metadata_generated.pb.h"
#include "spectoproto/task/task_generated.pb.h"
#include "spectoproto/termination/termination_metadata_generated.pb.h"
#include "spectoproto/trace/trace_metadata_generated.pb.h"

#include <google/protobuf/message_lite.h>

using namespace specto;

TEST(ProtobufTest, TestGlobalConfigSerializationDeserialization) {
    auto path = filesystem::temporaryDirectoryPath();
    path.appendComponent("config");

    proto::GlobalConfiguration configuration;
    configuration.set_enabled(true);

    configuration.mutable_persistence()->set_max_cache_age_ms(1);
    configuration.mutable_persistence()->set_max_cache_count(2);
    configuration.mutable_persistence()->set_min_disk_space_bytes(3);

    configuration.mutable_trace_upload()->set_foreground_trace_upload_enabled(false);
    configuration.mutable_trace_upload()->set_background_trace_upload_enabled(true);
    configuration.mutable_trace_upload()->set_cellular_trace_upload_enabled(false);

    // test that it is successully serialized
    EXPECT_TRUE(protobuf::serializeProtobufToDataAtPath(configuration, path));

    // test that it is deserialized and all the values match the originals
    const auto deserializedConfiguration =
      protobuf::deserializedProtobufDataAtPath<proto::GlobalConfiguration>(path);
    EXPECT_TRUE(deserializedConfiguration.has_value());

    EXPECT_EQ(configuration.enabled(), deserializedConfiguration->enabled());

    EXPECT_EQ(configuration.persistence().max_cache_age_ms(),
              deserializedConfiguration->persistence().max_cache_age_ms());
    EXPECT_EQ(configuration.persistence().max_cache_count(),
              deserializedConfiguration->persistence().max_cache_count());
    EXPECT_EQ(configuration.persistence().min_disk_space_bytes(),
              deserializedConfiguration->persistence().min_disk_space_bytes());

    EXPECT_EQ(configuration.trace_upload().foreground_trace_upload_enabled(),
              deserializedConfiguration->trace_upload().foreground_trace_upload_enabled());
    EXPECT_EQ(configuration.trace_upload().background_trace_upload_enabled(),
              deserializedConfiguration->trace_upload().background_trace_upload_enabled());
    EXPECT_EQ(configuration.trace_upload().cellular_trace_upload_enabled(),
              deserializedConfiguration->trace_upload().cellular_trace_upload_enabled());
}

TEST(ProtobufTest, TestMakeEntryTypes) {
    // clang-format off
    const std::vector<proto::Entry_Type> types {
      proto::Entry_Type_TRACE_START,
      proto::Entry_Type_TRACE_END,
      proto::Entry_Type_TRACE_FAILURE,
      proto::Entry_Type_BACKTRACE,
      proto::Entry_Type_TASK_CALL,          proto::Entry_Type_TRACE_ANNOTATION,
      proto::Entry_Type_SPAN_START,
      proto::Entry_Type_SPAN_END,
      proto::Entry_Type_SPAN_ANNOTATION,    proto::Entry_Type_NETWORK_REQUEST,
      proto::Entry_Type_MEMORY_FOOTPRINT,   proto::Entry_Type_MEMORY_PRESSURE,
      proto::Entry_Type_SESSION_START,
      proto::Entry_Type_SESSION_END,
      proto::Entry_Type_DEVICE_INFO,        proto::Entry_Type_PREMAIN_STARTUP_TIME,
      proto::Entry_Type_TOTAL_STARTUP_TIME, proto::Entry_Type_MAIN_THREAD_STALL,
      proto::Entry_Type_CPU_INFO,           proto::Entry_Type_MEMORY_MAPPED_IMAGES,
      proto::Entry_Type_RINGBUFFER_METRICS,
      proto::Entry_Type_APP_INFO,
      proto::Entry_Type_ANDROID_TRACE,
      proto::Entry_Type_TERMINATION,
    };
    // clang-format on

    const auto group = "test-group";
    std::for_each(types.begin(), types.end(), [&group](proto::Entry_Type type) {
        const auto entry = protobuf::makeEntry(type, group);
        EXPECT_EQ(entry.type(), type);
        EXPECT_EQ(entry.group_id(), group);
    });
}

TEST(ProtobufTest, TestMakeEntryWithDefaultGroup) {
    const auto entry =
      protobuf::makeEntry(proto::Entry_Type_TERMINATION); // we don't care about the type here
    EXPECT_EQ(entry.group_id(), "");
}
