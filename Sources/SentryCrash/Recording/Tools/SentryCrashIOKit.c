#if SentryCrashCRASH_HOST_MAC
#include "SentryCrashIOKit.h"
#include "SentryCrashLogger.h"

static bool
sentrycrashiokit_findEthernetInterfaces(io_iterator_t *matchingServices)
{
    CFMutableDictionaryRef matchingDict = IOServiceMatching(kIOEthernetInterfaceClass);

    if (matchingDict == NULL) {
        SentryCrashLOG_ERROR("Failed to find ethernet IOService");
        return false;
    }

    CFMutableDictionaryRef propertyMatchDict = CFDictionaryCreateMutable(
        NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);

    CFDictionarySetValue(propertyMatchDict, CFSTR(kIOPrimaryInterface), kCFBooleanTrue);
    CFDictionarySetValue(matchingDict, CFSTR(kIOPropertyMatchKey), propertyMatchDict);
    CFRelease(propertyMatchDict);

    kern_return_t ret
        = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, matchingServices);
    if (ret != KERN_SUCCESS) {
        SentryCrashLOG_ERROR("IOServiceGetMatchingServices failed with error 0x%08x", ret);
        return false;
    }

    return true;
}

bool
sentrycrashiokit_getPrimaryInterfaceMacAddress(char *const macAddressBuffer)
{
    // See
    // https://developer.apple.com/library/archive/samplecode/GetPrimaryMACAddress/Listings/GetPrimaryMACAddress_GetPrimaryMACAddress_c.html#//apple_ref/doc/uid/DTS10000698-GetPrimaryMACAddress_GetPrimaryMACAddress_c-DontLinkElementID_3
    // for reference
    io_iterator_t interfaceIterator;
    if (!sentrycrashiokit_findEthernetInterfaces(&interfaceIterator)) {
        SentryCrashLOG_ERROR("Failed to find the ethernet interface iterator");
        return false;
    }

    io_object_t interfaceService;
    kern_return_t ret = KERN_FAILURE;
    while ((interfaceService = IOIteratorNext(interfaceIterator))) {

        io_object_t controllerService;
        ret = IORegistryEntryGetParentEntry(interfaceService, kIOServicePlane, &controllerService);
        if (ret != KERN_SUCCESS) {
            SentryCrashLOG_WARN("IORegistryEntryGetParentEntry failed with error 0x%08x", ret);
        }

        CFTypeRef macAddressData = IORegistryEntryCreateCFProperty(
            controllerService, CFSTR(kIOMACAddress), kCFAllocatorDefault, 0);
        if (macAddressData) {
            CFDataGetBytes(macAddressData, CFRangeMake(0, CFDataGetLength(macAddressData)),
                (UInt8 *)macAddressBuffer);
            CFRelease(macAddressData);
        }

        IOObjectRelease(controllerService);
    }

    IOObjectRelease(interfaceIterator);

    return ret == KERN_SUCCESS;
}
#endif
