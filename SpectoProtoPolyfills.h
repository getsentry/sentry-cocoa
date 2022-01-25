//
//  SpectoProtoPolyfills.hpp
//  Sentry
//
//  Created by Andrew McKnight on 1/20/22.
//  Copyright © 2022 Sentry. All rights reserved.
//

#pragma once

#include <string>

namespace specto::proto {

class Backtrace {
public:
    void set_priority(int);
    void set_thread_name(std::string);
    void set_queue_name(std::string);
private:
    class Impl;
};

class Entry {
public:
    void set_tid(uint64_t);
    Backtrace* mutable_backtrace();
private:
    class Impl;
};

} // namespace specto::proto
