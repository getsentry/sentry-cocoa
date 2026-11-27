#import <Foundation/Foundation.h>

/// Identifies the direction and role of an HTTP body for collection purposes.
typedef NS_OPTIONS(NSUInteger, SentryObjCDataCollectionHttpBodyType) {
    /// Body of an incoming HTTP request (server-side).
    SentryObjCDataCollectionHttpBodyTypeIncomingRequest = 1 << 0,
    /// Body of an outgoing HTTP request (client-side).
    SentryObjCDataCollectionHttpBodyTypeOutgoingRequest = 1 << 1,
    /// Body of an incoming HTTP response (client-side).
    SentryObjCDataCollectionHttpBodyTypeIncomingResponse = 1 << 2,
    /// Body of an outgoing HTTP response (server-side).
    SentryObjCDataCollectionHttpBodyTypeOutgoingResponse = 1 << 3,
    /// All body types.
    SentryObjCDataCollectionHttpBodyTypeAll = SentryObjCDataCollectionHttpBodyTypeIncomingRequest
        | SentryObjCDataCollectionHttpBodyTypeOutgoingRequest
        | SentryObjCDataCollectionHttpBodyTypeIncomingResponse
        | SentryObjCDataCollectionHttpBodyTypeOutgoingResponse
};
