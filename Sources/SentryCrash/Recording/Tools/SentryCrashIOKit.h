#ifndef SentryCrashIOKit_h
#define SentryCrashIOKit_h

#ifdef __cplusplus
extern "C" {
#endif

#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>

#include <IOKit/IOKitLib.h>
#include <IOKit/network/IOEthernetController.h>
#include <IOKit/network/IOEthernetInterface.h>
#include <IOKit/network/IONetworkInterface.h>

/** Get the MAC address of the primary interface.
 *
 * @param macAddressBuffer 6 bytes of storage to hold the MAC address.
 *
 * @return true if the address was successfully retrieved.
 */
bool sentrycrashiokit_getPrimaryInterfaceMacAddress(char *const macAddressBuffer);

#ifdef __cplusplus
}
#endif

#endif /* SentryCrashIOKit_h */
