#pragma once

#include "spdlog/details/null_mutex.h"
#include "spdlog/sinks/base_sink.h"

#include <functional>
#include <mutex>

namespace specto {
namespace sinks {

    template <typename Mutex> class log_hook_sink : public spdlog::sinks::base_sink<Mutex> {
    public:
        explicit log_hook_sink(
            std::function<void(spdlog::level::level_enum, const spdlog::source_loc &, std::string)>
                messageHandler,
            std::function<void()> flushHandler)
            : messageHandler_(std::move(messageHandler))
            , flushHandler_(std::move(flushHandler)) {};

    protected:
        void
        sink_it_(const spdlog::details::log_msg &msg) override
        {
            if (!messageHandler_) {
                return;
            }
            spdlog::memory_buf_t formatted;
            spdlog::sinks::base_sink<Mutex>::formatter_->format(msg, formatted);
            messageHandler_(msg.level, msg.source, fmt::to_string(formatted));
        }

        void
        flush_() override
        {
            if (flushHandler_) {
                flushHandler_();
            }
        }

    private:
        std::function<void(spdlog::level::level_enum, const spdlog::source_loc &, std::string)>
            messageHandler_;
        std::function<void()> flushHandler_;
    };

    using log_hook_sink_mt = log_hook_sink<std::mutex>;
    using log_hook_sink_st = log_hook_sink<spdlog::details::null_mutex>;

} // namespace sinks
} // namespace specto
