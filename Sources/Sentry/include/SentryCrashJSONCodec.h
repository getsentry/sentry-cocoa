// Compatibility shim — forwards to upstream KSCrash KSJSONCodec.

#ifndef HDR_SentryCrashJSONCodec_h
#define HDR_SentryCrashJSONCodec_h

#include "KSJSONCodec.h"

#ifdef __cplusplus
extern "C" {
#endif

// Type aliases
#define SentryCrashJSONEncodeContext KSJSONEncodeContext
#define SentryCrashJSONAddDataFunc KSJSONAddDataFunc

// Constant aliases
#define SentryCrashJSON_SIZE_AUTOMATIC KSJSON_SIZE_AUTOMATIC
#define SentryCrashJSON_OK KSJSON_OK
#define SentryCrashJSON_ERROR_CANNOT_ADD_DATA KSJSON_ERROR_CANNOT_ADD_DATA

// Function aliases
#define sentrycrashjson_beginEncode ksjson_beginEncode
#define sentrycrashjson_endEncode ksjson_endEncode
#define sentrycrashjson_addBooleanElement ksjson_addBooleanElement
#define sentrycrashjson_addIntegerElement ksjson_addIntegerElement
#define sentrycrashjson_addUIntegerElement ksjson_addUIntegerElement
#define sentrycrashjson_addFloatingPointElement ksjson_addFloatingPointElement
#define sentrycrashjson_addStringElement ksjson_addStringElement
#define sentrycrashjson_addTextElement ksjson_addTextElement
#define sentrycrashjson_addDataElement ksjson_addDataElement
#define sentrycrashjson_addNullElement ksjson_addNullElement
#define sentrycrashjson_beginObject ksjson_beginObject
#define sentrycrashjson_beginArray ksjson_beginArray
#define sentrycrashjson_endContainer ksjson_endContainer
#define sentrycrashjson_stringForError ksjson_stringForError

#ifdef __cplusplus
}
#endif

#endif // HDR_SentryCrashJSONCodec_h
