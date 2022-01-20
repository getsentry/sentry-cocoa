// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#include <chrono>
#include <functional>
#include <memory>

namespace specto {
/** A task managed by a Scheduler that can be cancelled */
class CancellableTask {
public:
    /** Cancels the task. */
    virtual void cancel() noexcept = 0;

    virtual ~CancellableTask() = 0;
};

/** A scheduler is used to control when and where work is performed. */
class Scheduler {
public:
    /**
     * Schedules a task that repeats at a specified interval.
     * @param interval The repetition interval.
     * @param leeway Hint for an amount of time that the task can be deferred for improved
     * system performance and power consumption. This parameter may be ignored.
     * @param function The function to call every `interval`
     * @return A task object that can be used to cancel the task.
     */
    virtual std::shared_ptr<CancellableTask>
      scheduleRepeatingTask(std::chrono::nanoseconds interval,
                            std::chrono::nanoseconds leeway,
                            std::function<void(void)> function) noexcept = 0;

    virtual ~Scheduler() = 0;
};
} // namespace specto
