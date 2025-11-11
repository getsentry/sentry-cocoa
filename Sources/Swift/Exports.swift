// This file is only for SPM, it allows all Swift
// files to use code in SentryHeaders without needing
// to add an import. This allows the same source to
// compile in SPM and xcodebuild (which doesn't separate
// ObjC into the SentryHeaders target)
#if !COCOAPODS
@_exported import SentryHeaders
#endif
