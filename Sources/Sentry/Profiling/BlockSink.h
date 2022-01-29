#pragma once

#include "spdlog/spdlog.h"

#include <functional>
#include <mutex>
#include <spdlog/details/null_mutex.h>
#include <spdlog/sinks/base_sink.h>
#include <string>

namespace specto {
namespace sinks {

    template <typename Mutex> class block_sink final : public spdlog::sinks::base_sink<Mutex> {
    public:
        explicit block_sink(std::function<void(void)> function)
            : function_(std::move(function)) {};

    protected:
        void
        sink_it_(__unused const spdlog::details::log_msg &msg) override
        {
            function_();
        }
        void
        flush_() override
        {
            // no-op
        }

    private:
        std::function<void(void)> function_;
    };

    using block_sink_mt = block_sink<std::mutex>;
    using block_sink_st = block_sink<spdlog::details::null_mutex>;

} // namespace sinks
} // namespace specto
