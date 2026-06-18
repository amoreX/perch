import CoreGraphics
import XCTest
@testable import Perch

final class WidgetGridLayoutTests: XCTestCase {
    func testTargetIndexReturnsContainingCell() {
        let frames = [
            WidgetGridItemFrame(index: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 1, frame: CGRect(x: 110, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 2, frame: CGRect(x: 0, y: 90, width: 100, height: 80)),
        ]

        XCTAssertEqual(
            WidgetGridLayout.targetIndex(at: CGPoint(x: 140, y: 30), in: frames),
            1
        )
    }

    func testTargetIndexUsesNearestCellWhenOutsideGrid() {
        let frames = [
            WidgetGridItemFrame(index: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 1, frame: CGRect(x: 110, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 2, frame: CGRect(x: 0, y: 90, width: 100, height: 80)),
        ]

        XCTAssertEqual(
            WidgetGridLayout.targetIndex(at: CGPoint(x: 10, y: 220), in: frames),
            2
        )
    }

    func testTargetIndexTreatsOddRowTrailingSlotAsEnd() {
        let frames = [
            WidgetGridItemFrame(index: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 1, frame: CGRect(x: 110, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 2, frame: CGRect(x: 0, y: 90, width: 100, height: 80)),
        ]

        XCTAssertEqual(
            WidgetGridLayout.targetIndex(at: CGPoint(x: 150, y: 120), in: frames),
            2
        )
    }

    func testTargetIndexHandlesHorizontalAndVerticalGaps() {
        let frames = [
            WidgetGridItemFrame(index: 0, frame: CGRect(x: 0, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 1, frame: CGRect(x: 110, y: 0, width: 100, height: 80)),
            WidgetGridItemFrame(index: 2, frame: CGRect(x: 0, y: 90, width: 100, height: 80)),
            WidgetGridItemFrame(index: 3, frame: CGRect(x: 110, y: 90, width: 100, height: 80)),
        ]

        XCTAssertEqual(
            WidgetGridLayout.targetIndex(at: CGPoint(x: 105, y: 40), in: frames),
            0
        )
        XCTAssertEqual(
            WidgetGridLayout.targetIndex(at: CGPoint(x: 50, y: 85), in: frames),
            0
        )
    }

    func testReorderMovesItemForward() {
        XCTAssertEqual(
            WidgetGridLayout.reorder(["calendar", "music", "ram", "disk"], movingFrom: 0, to: 2),
            ["music", "ram", "calendar", "disk"]
        )
    }

    func testReorderMovesItemBackward() {
        XCTAssertEqual(
            WidgetGridLayout.reorder(["calendar", "music", "ram", "disk"], movingFrom: 3, to: 1),
            ["calendar", "disk", "music", "ram"]
        )
    }

    func testReorderIgnoresInvalidOrNoopMoves() {
        XCTAssertEqual(WidgetGridLayout.reorder(["calendar"], movingFrom: 0, to: 0), ["calendar"])
        XCTAssertEqual(WidgetGridLayout.reorder(["calendar"], movingFrom: 0, to: 1), ["calendar"])
        XCTAssertEqual(WidgetGridLayout.reorder(["calendar"], movingFrom: 1, to: 0), ["calendar"])
    }
}
