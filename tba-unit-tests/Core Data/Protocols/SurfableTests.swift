import XCTest
@testable import The_Blue_Alliance

private class MockSurfable: Surfable {
    var website: String?
}

class SurfableTests: XCTestCase {

    func test_surfable() {
        let surfable = MockSurfable()
        surfable.website = "abc"
        XCTAssert(surfable.hasWebsite)

        let notSurfable = MockSurfable()
        XCTAssertFalse(notSurfable.hasWebsite)
    }

}
