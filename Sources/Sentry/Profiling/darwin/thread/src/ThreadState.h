// Copyright (c) Specto Inc. All rights reserved.

#pragma once

#ifndef __APPLE__
#error Non-Apple platforms are not supported!
#endif

#include "ThreadHandle.h"
#include "cpp/portability/src/CPU.h"
#include "cpp/portability/src/Compiler.h"
#include "cpp/stack/src/StackFrame.h"

#include <cstdint>
#include <mach/mach.h>
#include <sys/types.h>

namespace specto {
namespace darwin {
namespace thread {

using MachineContext = _STRUCT_MCONTEXT;

/**
 * Fills in thread state information in the specified machine context structure.
 *
 * @param thread The thread to get state information from.
 * @param context The machine context structure to fill state information into.
 * @return Kernel return code indicating success or failure.
 */
ALWAYS_INLINE kern_return_t fillThreadState(ThreadHandle::NativeHandle thread,
                                            MachineContext *context) noexcept {
#if CPU(X86_64)
#define SPECTO_THREAD_STATE_COUNT x86_THREAD_STATE64_COUNT
#define SPECTO_THREAD_STATE_FLAVOR x86_THREAD_STATE64
#elif CPU(X86)
#define SPECTO_THREAD_STATE_COUNT x86_THREAD_STATE32_COUNT
#define SPECTO_THREAD_STATE_FLAVOR x86_THREAD_STATE32
#elif CPU(ARM64)
#define SPECTO_THREAD_STATE_COUNT ARM_THREAD_STATE64_COUNT
#define SPECTO_THREAD_STATE_FLAVOR ARM_THREAD_STATE64
#elif CPU(ARM)
#define SPECTO_THREAD_STATE_COUNT ARM_THREAD_STATE_COUNT
#define SPECTO_THREAD_STATE_FLAVOR ARM_THREAD_STATE
#else
#error Unsupported architecture!
#endif
    mach_msg_type_number_t count = SPECTO_THREAD_STATE_COUNT;
    return thread_get_state(
      thread, SPECTO_THREAD_STATE_FLAVOR, (thread_state_t)&context->__ss, &count);
}

/**
 * Returns the frame address value from the specified machine context.
 *
 * @param context Machine context to get frame address from.
 * @return The frame address value.
 */
ALWAYS_INLINE std::uintptr_t getFrameAddress(const MachineContext *context) noexcept {
    // Program must be compiled with `-fno-omit-frame-pointer` to avoid
    // frame pointer optimization.
    // https://gcc.gnu.org/onlinedocs/gcc-4.9.2/gcc/Optimize-Options.html
    // http://www.keil.com/support/man/docs/armclang_ref/armclang_ref_vvi1466179578564.htm
#if CPU(X86_64)
    return context->__ss.__rbp;
#elif CPU(X86)
    return context->__ss.__ebp;
#elif CPU(ARM64)
    // fp is an alias for frame pointer register x29:
    // https://developer.apple.com/library/archive/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARM64FunctionCallingConventions.html
    return context->__ss.__fp;
#elif CPU(ARM)
    // https://developer.apple.com/library/archive/documentation/Xcode/Conceptual/iPhoneOSABIReference/Articles/ARMv6FunctionCallingConventions.html#//apple_ref/doc/uid/TP40009021-SW1
    return context->__ss.__r[7];
#else
#error Unsupported architecture!
#endif
} // namespace thread

/**
 * Returns the return address of the current function.
 *
 * @param context Machine context to get the program counter value from.
 * @return The return address of the current function, i.e. the address of the
 * calling function.
 */
ALWAYS_INLINE std::uintptr_t getReturnAddress(const MachineContext *context) noexcept {
    const auto frameAddress = getFrameAddress(context);
    return reinterpret_cast<const StackFrame *>(frameAddress)->returnAddress;
} // namespace darwin

/**
 * Returns the contents of the link register from the specified machine context.
 * The link register is used on some CPU architectures to store a return address.
 *
 * @param context Machine context to get link register value from.
 * @return Contents of the link register.
 */
#if CPU(ARM64) || CPU(ARM)
ALWAYS_INLINE std::uintptr_t getLinkRegister(const MachineContext *context) noexcept {
    // https://stackoverflow.com/a/8236974
    return context->__ss.__lr;
#else
ALWAYS_INLINE std::uintptr_t getLinkRegister(__unused const MachineContext *context) noexcept {
    return 0;
#endif
} // namespace thread

/**
 * Returns the contents of the program counter from the specified machine context.
 *
 * @param context Machine context to get the program counter value from.
 * @return Contents of the program counter.
 */
ALWAYS_INLINE std::uintptr_t getProgramCounter(const MachineContext *context) noexcept {
#if CPU(ARM64) || CPU(ARM)
    return context->__ss.__pc;
#elif CPU(X86_64)
    return context->__ss.__rip;
#elif CPU(X86)
    return context->__ss.__eip;
#else
#error Unsupported architecture!
#endif
}
} // namespace thread
} // namespace darwin
} // namespace specto
