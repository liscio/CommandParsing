import XCTest
@testable import CommandParsing

final class CommandParsingTests: XCTestCase {
    func testParsingMeasureDistance() throws {
        let p = CommandParser.default
        
        let c = try p.parse("measureDistance(to: start, using: inches, percentAccuracy: 98)")
        XCTAssertEqual(c, .measureDistance(to: .start, using: .inches, percentAccuracy: 98))
    }
    
    func testParsingClearDistance() throws {
        let p = CommandParser.default
        
        let c = try p.parse("clearMeasurement(to: end)")
        XCTAssertEqual(c, .clearMeasurement(to: .end))
    }
}
