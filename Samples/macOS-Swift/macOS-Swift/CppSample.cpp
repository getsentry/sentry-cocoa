#include "CppSample.hpp"
#include <stdexcept>

void
internalFunction(void)
{
    throw std::invalid_argument("Invalid Argument.");
}

void
Sentry::CppSample::throwCPPException(void)
{
    internalFunction();
}
