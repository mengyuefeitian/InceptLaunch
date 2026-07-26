import CoreGraphics
import Testing
@testable import InceptLaunch

/// Regression: live-reorder already moves layout frames; merge hit-testing must
/// use the pointer, not layoutFrame+translation (that double-counts Y and hits
/// the row below the visual ghost when merging across rows).
@Test func draggedFrameIsCenteredOnPointer() {
    let frames = [
        TileFrameInfo(id: "a", frame: CGRect(x: 100, y: 200, width: 120, height: 150), isFolder: false)
    ]
    let pointer = CGPoint(x: 400, y: 500)
    let rect = DragMergeGeometry.draggedFrame(sourceID: "a", pointer: pointer, tileFrames: frames)
    #expect(rect.width == 120)
    #expect(rect.height == 150)
    #expect(abs(rect.midX - pointer.x) < 0.5)
    #expect(abs(rect.midY - pointer.y) < 0.5)
}

@Test func draggedFrameFallsBackWhenSourceFrameMissing() {
    let pointer = CGPoint(x: 50, y: 60)
    let rect = DragMergeGeometry.draggedFrame(sourceID: "missing", pointer: pointer, tileFrames: [])
    #expect(rect.width == 104)
    #expect(rect.height == 104)
    #expect(abs(rect.midX - 50) < 0.5)
    #expect(abs(rect.midY - 60) < 0.5)
}

@Test func pointerCenteredFramePrefersRowUnderCursorNotDoubleCountedOffset() {
    // Source layout frame already moved to row-like y=300 (live reorder).
    // Finger is also around y=300. Double-counting translation of +180 would
    // incorrectly center near y=480 (next row).
    let frames = [
        TileFrameInfo(id: "src", frame: CGRect(x: 100, y: 300, width: 100, height: 140), isFolder: false),
        TileFrameInfo(id: "row3", frame: CGRect(x: 100, y: 280, width: 100, height: 140), isFolder: false),
        TileFrameInfo(id: "row4", frame: CGRect(x: 100, y: 460, width: 100, height: 140), isFolder: false)
    ]
    let pointer = CGPoint(x: 150, y: 350)
    let dragged = DragMergeGeometry.draggedFrame(sourceID: "src", pointer: pointer, tileFrames: frames)
    let r3 = DragMergeGeometry.overlapRatio(dragged: dragged, target: frames[1].frame)
    let r4 = DragMergeGeometry.overlapRatio(dragged: dragged, target: frames[2].frame)
    #expect(r3 > r4)
    #expect(r3 > 0.35)
}
