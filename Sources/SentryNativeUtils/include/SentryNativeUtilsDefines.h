#pragma once

#ifdef __cplusplus
#    define SENTRY_EXTERN_C_BEGIN extern "C" {
#    define SENTRY_EXTERN_C_END }
#else
#    define SENTRY_EXTERN_C_BEGIN
#    define SENTRY_EXTERN_C_END
#endif
