// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <google/protobuf/message.h>

namespace specto {
namespace test {

/**
 * Compares the equality of two protobuf messages and prints the report to stdout.
 * @param message1 The first message.
 * @param message2 The second message.
 * @return Whether the two messages are equal.
 */
bool compareProtobufAndReport(const google::protobuf::Message &message1,
                              const google::protobuf::Message &message2);

} // namespace test
} // namespace specto
