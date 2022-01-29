namespace specto {
namespace darwin {

    namespace thread {

        /**
         * The priority of the system-created main thread.
         * This was measured by calling `pthread_getschedparam()` on the main thread in an
         * iOS app. Ideally, we should be determining this value dynamically in case it changes.
         */
        constexpr int mainThreadPriority = 31;

        /**
         * The priority that the buffer consumer thread runs at.
         *
         * Run at a higher priority than the backtrace thread so that it doesn't overrun
         * the ring buffer with data that isn't being consumed.
         * @see `SpectoTraceController`
         */
        constexpr int bufferConsumerThreadPriority = 60;

        /**
         * The priority that the backtrace collection thread runs at.
         * A priority of 50 is higher than user input, according to:
         * https://chromium.googlesource.com/chromium/src/base/+/master/threading/platform_thread_mac.mm#302
         *
         * Run at a higher priority than the main thread so that we can capture main thread
         * backtraces even when it's busy.
         * @see `BacktracePlugin`.
         */
        constexpr int backtraceThreadPriority = 50;

    } // namespace thread
} // namespace darwin
} // namespace specto
