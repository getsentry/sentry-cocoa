#include "CppSample.hpp"
#include <stdexcept>

void
internalFunction()
{
    throw std::invalid_argument("Invalid Argument.");
}

void
Sentry::CppSample::throwCPPException()
{
    internalFunction();
}
