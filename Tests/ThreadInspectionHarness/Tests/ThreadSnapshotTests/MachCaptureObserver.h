#include <mach/mach.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct {
    size_t suspendAttempts;
    size_t suspensions;
    size_t resumptions;
    size_t active;
    size_t maxActive;
    bool touchedReserved;
    bool touchedCurrent;
} MachCaptureObservation;

// Test-bundle definitions of the Mach entry points intercept RecordingCore's static object calls.
// All symbol resolution/TLS initialization is performed before any target is suspended.
void beginMachCaptureObservation(thread_t failSuspend, thread_t failState);
MachCaptureObservation endMachCaptureObservation(void);
