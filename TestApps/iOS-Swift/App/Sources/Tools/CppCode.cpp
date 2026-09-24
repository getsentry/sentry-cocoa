#include "CppCode.hpp"
#include <stdexcept>

void
Sentry::CppCode::throwCPPException(void)
{
    throw std::invalid_argument("Invalid Argument.");
}
