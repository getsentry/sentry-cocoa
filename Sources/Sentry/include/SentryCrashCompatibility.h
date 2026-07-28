// Compatibility layer for compiling in KSCrash mode, excluding SentryCrash.
// There are some SentryCrash APIs used outside of SentryCrash, this header
// maps those used functions to KSCrash equivilents (were possible) during
// the migration. Where a direct equivilent is not avaliable, a stub function
// is defined here which provides the same functionality.
//
// When compiling without KSCrash, the SentryCrash headers provide the definitions

#ifndef SentryCrashCompatibility_h
#define SentryCrashCompatibility_h

#if ENABLE_KSCRASH

// ============================================================================
// KSCrash Mode: Map SentryCrash APIs to KSCrash equivalents
// ============================================================================

// C headers (safe for both C and ObjC)
#    include <KSDate.h>
#    include <KSDebug.h>
#    include <KSDynamicLinker.h>
#    include <KSFileUtils.h>
#    include <KSID.h>
#    include <KSJSONCodec.h>
#    include <KSMach.h>
#    include <KSMemory.h>
#    include <KSString.h>
#    include <KSSysCtl.h>
#    include <KSThread.h>
#    include <unistd.h>

// ObjC headers (only when compiling ObjC/ObjC++)
#    ifdef __OBJC__
#        import <KSJSONCodecObjC.h>
#    endif

// JSON Codec (C API)
#    define SentryCrashJSON_SIZE_AUTOMATIC KSJSON_SIZE_AUTOMATIC
#    define SentryCrashMAX_STRINGBUFFERSIZE KSMAXSTRINGBUFFERSIZE

#    define SentryCrashJSON_OK KSJSON_OK
#    define SentryCrashJSON_ERROR_INVALID_CHARACTER KSJSON_ERROR_INVALID_CHARACTER
#    define SentryCrashJSON_ERROR_DATA_TOO_LONG KSJSON_ERROR_DATA_TOO_LONG
#    define SentryCrashJSON_ERROR_CANNOT_ADD_DATA KSJSON_ERROR_CANNOT_ADD_DATA
#    define SentryCrashJSON_ERROR_INCOMPLETE KSJSON_ERROR_INCOMPLETE
#    define SentryCrashJSON_ERROR_INVALID_DATA KSJSON_ERROR_INVALID_DATA

#    define sentrycrashjson_stringForError ksjson_stringForError

#    define SentryCrashJSONAddDataFunc KSJSONAddDataFunc
#    define SentryCrashJSONEncodeContext KSJSONEncodeContext

#    define sentrycrashjson_beginEncode ksjson_beginEncode
#    define sentrycrashjson_endEncode ksjson_endEncode
#    define sentrycrashjson_addBooleanElement ksjson_addBooleanElement
#    define sentrycrashjson_addIntegerElement ksjson_addIntegerElement
#    define sentrycrashjson_addUIntegerElement ksjson_addUIntegerElement
#    define sentrycrashjson_addFloatingPointElement ksjson_addFloatingPointElement
#    define sentrycrashjson_addNullElement ksjson_addNullElement
#    define sentrycrashjson_addStringElement ksjson_addStringElement
#    define sentrycrashjson_beginStringElement ksjson_beginStringElement
#    define sentrycrashjson_appendStringElement ksjson_appendStringElement
#    define sentrycrashjson_endStringElement ksjson_endStringElement
#    define sentrycrashjson_addDataElement ksjson_addDataElement
#    define sentrycrashjson_beginDataElement ksjson_beginDataElement
#    define sentrycrashjson_appendDataElement ksjson_appendDataElement
#    define sentrycrashjson_endDataElement ksjson_endDataElement
#    define sentrycrashjson_addJSONElement ksjson_addJSONElement
#    define sentrycrashjson_beginObject ksjson_beginObject
#    define sentrycrashjson_beginArray ksjson_beginArray
#    define sentrycrashjson_beginElement ksjson_beginElement
#    define sentrycrashjson_addRawJSONData ksjson_addRawJSONData
#    define sentrycrashjson_endContainer ksjson_endContainer
#    define sentrycrashjson_addJSONFromFile ksjson_addJSONFromFile

#    define SentryCrashJSONDecodeCallbacks KSJSONDecodeCallbacks
#    define sentrycrashjson_decode ksjson_decode

// JSON Codec (ObjC API) - only available in ObjC
#    ifdef __OBJC__
#        define SentryCrashJSONCodec KSJSONCodec
#        define SentryCrashJSONEncodeOption KSJSONEncodeOption
#        define SentryCrashJSONEncodeOptionSorted KSJSONEncodeOptionSorted
#        define SentryCrashJSONEncodeOptionPretty KSJSONEncodeOptionPretty
#    endif

// File Utils
#    define SentryCrashFU_MAX_PATH_LENGTH KSFU_MAX_PATH_LENGTH

#    define sentrycrashfu_lastPathEntry ksfu_lastPathEntry
#    define sentrycrashfu_writeBytesToFD ksfu_writeBytesToFD
#    define sentrycrashfu_readBytesFromFD ksfu_readBytesFromFD
#    define sentrycrashfu_readEntireFile ksfu_readEntireFile
#    define sentrycrashfu_writeStringToFD ksfu_writeStringToFD
#    define sentrycrashfu_writeFmtToFD ksfu_writeFmtToFD
#    define sentrycrashfu_writeFmtArgsToFD ksfu_writeFmtArgsToFD
#    define sentrycrashfu_readLineFromFD ksfu_readLineFromFD
#    define sentrycrashfu_makePath ksfu_makePath
#    define sentrycrashfu_makePathInPlace ksfu_makePathInPlace
#    define sentrycrashfu_removeFile ksfu_removeFile
#    define sentrycrashfu_deleteContentsOfPath ksfu_deleteContentsOfPath

#    define SentryCrashBufferedWriter KSBufferedWriter
#    define sentrycrashfu_openBufferedWriter ksfu_openBufferedWriter
#    define sentrycrashfu_closeBufferedWriter ksfu_closeBufferedWriter
#    define sentrycrashfu_writeBufferedWriter ksfu_writeBufferedWriter
#    define sentrycrashfu_flushBufferedWriter ksfu_flushBufferedWriter

#    define SentryCrashBufferedReader KSBufferedReader
#    define sentrycrashfu_openBufferedReader ksfu_openBufferedReader
#    define sentrycrashfu_closeBufferedReader ksfu_closeBufferedReader
#    define sentrycrashfu_readBufferedReader ksfu_readBufferedReader
#    define sentrycrashfu_readBufferedReaderUntilChar ksfu_readBufferedReaderUntilChar

// SysCtl
#    define sentrycrashsysctl_int32 kssysctl_int32
#    define sentrycrashsysctl_int32ForName kssysctl_int32ForName
#    define sentrycrashsysctl_uint32 kssysctl_uint32
#    define sentrycrashsysctl_uint32ForName kssysctl_uint32ForName
#    define sentrycrashsysctl_int64 kssysctl_int64
#    define sentrycrashsysctl_int64ForName kssysctl_int64ForName
#    define sentrycrashsysctl_uint64 kssysctl_uint64
#    define sentrycrashsysctl_uint64ForName kssysctl_uint64ForName
#    define sentrycrashsysctl_string kssysctl_string
#    define sentrycrashsysctl_stringForName kssysctl_stringForName
#    define sentrycrashsysctl_timeval kssysctl_timeval
#    define sentrycrashsysctl_timevalForName kssysctl_timevalForName
#    define sentrycrashsysctl_currentProcessStartTime kssysctl_currentProcessStartTime
#    define sentrycrashsysctl_getProcessInfo kssysctl_getProcessInfo
#    define sentrycrashsysctl_getMacAddress kssysctl_getMacAddress

static inline struct timeval
sentrycrashsysctl_currentProcessStartTime(void)
{
    struct kinfo_proc kp;
    struct timeval value = { 0 };

    if (kssysctl_getProcessInfo(getpid(), &kp)) {
        value = kp.kp_proc.p_un.__p_starttime;
    }

    return value;
}

// Thread
#    define SentryCrashThread KSThread
#    define sentrycrashthread_self ksthread_self
#    define sentrycrashthread_getThreadName ksthread_getThreadName

// Dynamic Linker
#    define sentrycrashdl_getBinaryImageForHeader ksdl_getBinaryImageForHeader
#    define sentrycrashdl_imageNamed ksdl_imageNamed
#    define sentrycrashdl_imageUUID ksdl_imageUUID
#    define sentrycrashdl_getCrashInfo ksdl_getCrashInfo
#    define sentrycrashdl_initialize ksdl_initialize
#    define sentrycrashdl_convertBinaryImageUUID ksdl_convertBinaryImageUUID

// Date
#    define sentrycrashdate_utcStringFromTimestamp ksdate_utcStringFromTimestamp

// ID
#    define sentrycrashid_generate ksid_generate

// String
#    define sentrycrashstring_isNullTerminatedUTF8String ksstring_isNullTerminatedUTF8String
#    define sentrycrashstring_extractHexValue ksstring_extractHexValue

// Memory
#    define sentrycrashmem_isMemoryReadable ksmem_isMemoryReadable
#    define sentrycrashmem_maxReadableBytes ksmem_maxReadableBytes
#    define sentrycrashmem_copySafely ksmem_copySafely
#    define sentrycrashmem_copyMaxPossible ksmem_copyMaxPossible

// Debug
#    define sentrycrashdebug_isBeingTraced ksdebug_isBeingTraced

// Mach
#    define sentrycrashmach_exceptionName ksmach_exceptionName
#    define sentrycrashmach_kernelReturnCodeName ksmach_kernelReturnCodeName

#else

// ============================================================================
// SentryCrash Mode: Use original SentryCrash headers
// ============================================================================

#    include "SentryCrashDate.h"
#    include "SentryCrashDebug.h"
#    include "SentryCrashDynamicLinker.h"
#    include "SentryCrashFileUtils.h"
#    include "SentryCrashID.h"
#    include "SentryCrashJSONCodec.h"
#    include "SentryCrashMach.h"
#    include "SentryCrashMemory.h"
#    include "SentryCrashString.h"
#    include "SentryCrashSysCtl.h"
#    include "SentryCrashThread.h"

#    ifdef __OBJC__
#        import "SentryCrashJSONCodecObjC.h"
#    endif

#endif // ENABLE_KSCRASH

#endif // SentryCrashCompatibility_h
