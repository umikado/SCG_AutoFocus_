import XCTest
@testable import LCCore

final class PackageTests: XCTestCase {
    func testFoundationJSONAvailable() throws {
        let data = try JSONSerialization.data(withJSONObject: ["schema": 1])
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Int])
        XCTAssertEqual(object["schema"], 1)
    }
}
