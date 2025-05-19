#include "CppSample.hpp"
#include <stdexcept>

void
internalFunction(void)
{
    throw std::invalid_argument("Internal function must not be called.");
}

void
Sentry::CppSample::throwCPPException(void)
{
    internalFunction();
}

void
Sentry::CppSample::noExceptCppException() noexcept
{
    throw std::invalid_argument("Invalid Argument.");
}

void
Sentry::CppSample::rethrowNoActiveCPPException(void)
{
    // Rethrowing an exception when there is no active exception will lead to std::terminate being
    // called.
    throw;
}
