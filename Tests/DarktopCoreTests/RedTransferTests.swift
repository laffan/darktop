import XCTest
@testable import DarktopCore

final class RedTransferTests: XCTestCase {
    func testNormalTableRisesFromZeroToLevel() {
        let table = RedTransfer(level: 0.5, inverted: false).redTable(size: 256)
        XCTAssertEqual(table.count, 256)
        XCTAssertEqual(table.first, 0)
        XCTAssertEqual(table.last ?? -1, 0.5, accuracy: 1e-6)
        XCTAssertTrue(zip(table, table.dropFirst()).allSatisfy { $0 <= $1 })
    }

    func testInvertedTableFallsFromLevelToZero() {
        let table = RedTransfer(level: 1, inverted: true).redTable(size: 1024)
        XCTAssertEqual(table.first ?? -1, 1, accuracy: 1e-6)
        XCTAssertEqual(table.last ?? -1, 0, accuracy: 1e-6)
        XCTAssertTrue(zip(table, table.dropFirst()).allSatisfy { $0 >= $1 })
    }

    func testLevelIsClamped() {
        XCTAssertEqual(RedTransfer(level: 3, inverted: false).level, 1)
        XCTAssertEqual(RedTransfer(level: -1, inverted: false).level, 0)
    }

    func testTinyTableSizeIsRaisedToTwo() {
        XCTAssertEqual(RedTransfer(level: 1, inverted: false).redTable(size: 0), [0, 1])
    }

    func testSatisfiedByItsOwnTables() {
        let transfer = RedTransfer(level: 0.25, inverted: true)
        let red = transfer.redTable(size: 1024)
        let zeros = [Float](repeating: 0, count: 1024)
        XCTAssertTrue(transfer.isSatisfied(red: red, green: zeros, blue: zeros))
    }

    func testSatisfiedByResampledTable() {
        let transfer = RedTransfer(level: 1, inverted: false)
        let red = transfer.redTable(size: 256)
        let zeros = [Float](repeating: 0, count: 256)
        XCTAssertTrue(transfer.isSatisfied(red: red, green: zeros, blue: zeros))
    }

    func testAnyGreenOrBlueFailsTheCheck() {
        let transfer = RedTransfer(level: 1, inverted: false)
        let red = transfer.redTable(size: 256)
        var leaky = [Float](repeating: 0, count: 256)
        leaky[128] = 0.01
        let zeros = [Float](repeating: 0, count: 256)
        XCTAssertFalse(transfer.isSatisfied(red: red, green: leaky, blue: zeros))
        XCTAssertFalse(transfer.isSatisfied(red: red, green: zeros, blue: leaky))
    }

    func testIdentityTablesFailTheCheck() {
        let transfer = RedTransfer(level: 1, inverted: false)
        let identity = (0..<256).map { Float($0) / 255 }
        XCTAssertFalse(transfer.isSatisfied(red: identity, green: identity, blue: identity))
    }

    func testDifferentSettingsFailTheCheck() {
        let applied = RedTransfer(level: 1, inverted: false)
        let wanted = RedTransfer(level: 1, inverted: true)
        let zeros = [Float](repeating: 0, count: 256)
        XCTAssertFalse(wanted.isSatisfied(red: applied.redTable(size: 256), green: zeros, blue: zeros))
    }

    func testMismatchedLengthsFailTheCheck() {
        let transfer = RedTransfer(level: 1, inverted: false)
        XCTAssertFalse(transfer.isSatisfied(red: transfer.redTable(size: 4), green: [0, 0], blue: [0, 0, 0, 0]))
    }
}
