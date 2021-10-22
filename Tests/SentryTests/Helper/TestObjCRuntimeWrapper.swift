import Foundation

//class TestObjCRuntimeWrapper : SentryObjCRuntimeWrapper {
//
//    var numberOfRegisteredClasses : Int? = nil
//    override func getClassList(_ buffer: AutoreleasingUnsafeMutablePointer<AnyClass?>!, bufferCount: Int32) -> Int32 {
//
//        var actual: Int32 = 0
//        if (buffer == nil) {
//            actual = objc_getClassList(nil, bufferCount)
//        } else {
//
//            var clazz : AnyClass = buffer.pointee!
//            let pointer = UnsafeMutablePointer<AnyClass>.allocate(capacity: Int(bufferCount))
//            pointer.initialize(from: &clazz, count: Int(bufferCount))
//            let buf = AutoreleasingUnsafeMutablePointer<AnyClass>(pointer)
//            actual = objc_getClassList(buf, bufferCount)
//        }
//
//        return actual;
//    }
//}
