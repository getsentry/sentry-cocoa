//
//  UserFeedback.swift
//  SentrySwift
//
//  Created by Daniel Griesser on 16/11/16.
//
//

@objc public final class UserFeedback: NSObject {
    public var name = ""
    public var email = ""
    public var comments = ""
    public var event: Event?
}

extension UserFeedback {
    #if swift(>=3.0)
    internal typealias SerializedType = Data?
    #else
    internal typealias SerializedType = NSData?
    #endif
    
    internal var serialized: SerializedType {
        let urlEncodedString = "email=\(urlEncodeString(email))&name=\(urlEncodeString(name))&comments=\(urlEncodeString(comments))"
        #if swift(>=3.0)
        return urlEncodedString.data(using: String.Encoding.utf8)
        #else
        return urlEncodedString.dataUsingEncoding(NSUTF8StringEncoding)
        #endif
    }
    
    private func urlEncodeString(_ string: String) -> String {
        #if swift(>=3.0)
            let allowedCharacterSet = (CharacterSet(charactersIn: "!*'();:@&=+$,/?%#[] ").inverted)
            if let escapedString = string.addingPercentEncoding(withAllowedCharacters: allowedCharacterSet) {
                return escapedString
            }
        #else
            let allowedCharacterSet = (NSCharacterSet(charactersInString: "!*'();:@&=+$,/?%#[] ").invertedSet)
            if let escapedString = string.stringByAddingPercentEncodingWithAllowedCharacters(allowedCharacterSet) {
                return escapedString
            }
        #endif
        SentryLog.Error.log("Could not urlencode \(string)")
        return string
    }
    
    internal var queryItems: [URLQueryItem] {
        return [
            URLQueryItem(name: "email", value: urlEncodeString(email)),
            URLQueryItem(name: "eventId", value: event?.eventID)
        ]
    }
}
