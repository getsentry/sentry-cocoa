//
//  SpectoProtoPolyfills.cpp
//  Sentry
//
//  Created by Andrew McKnight on 1/20/22.
//  Copyright © 2022 Sentry. All rights reserved.
//

#include "SpectoProtoPolyfills.h"

namespace specto::proto {

class Backtrace::Impl {
public:
    void set_priority(int) {

    }

    void set_thread_name(std::string) {

    }

    void set_queue_name(std::string) {

    }
};

class Entry::Impl {
public:
    void set_tid(uint64_t) {

    }

    Backtrace* mutable_backtrace() {
        return nullptr;
    }
};

} // namespace specto::proto
