// Copyright (c) Specto Inc. All rights reserved.

#include "ProtobufComparison.h"

#include <google/protobuf/util/message_differencer.h>
#include <iostream>

using namespace google::protobuf;
using namespace google::protobuf::util;

namespace specto::test {

bool compareProtobufAndReport(const google::protobuf::Message &message1,
                              const google::protobuf::Message &message2) {
    auto differencer = MessageDifferencer();
    std::string output;
    differencer.ReportDifferencesToString(&output);
    const auto result = differencer.Compare(message1, message2);
    if (!result) {
        std::cout << "Protobuf comparison failed. Result: "
                  << "\n"
                  << output << "\n";
    }
    return result;
}

} // namespace specto::test
