@testable import SentryDistribution
import Testing

@Test func testBinaryParserGetsCorrectUUID() throws {
  let uuid = BinaryParser.getMainBinaryUUID { _, ptr in
    let mutable = UnsafeMutableRawPointer(mutating: ptr)
    for i in 0..<16 {
      // Use a fixed value of 10 so we can expect to see repeated 0x0A
      // in the resulting UUID.
      mutable.storeBytes(of: 10, toByteOffset: i, as: CChar.self)
    }
    return true
  }
  #expect(uuid == "0A0A0A0A-0A0A-0A0A-0A0A-0A0A0A0A0A0A")
}
