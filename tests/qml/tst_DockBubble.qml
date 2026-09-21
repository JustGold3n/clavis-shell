import QtQuick
import QtTest
import "../../Common/functions/DockBubble.js" as DockBubble

TestCase {
    name: "DockBubble"

    function contains(rects, x, y) {
        return rects.some(rect => x >= rect.x && x < rect.x + rect.width && y >= rect.y && y < rect.y
                                  + rect.height);
    }

    function test_blurIncludesTailButExcludesEmptyBoundingBox() {
        for (const edge of ["bottom", "left", "right"]) {
            const rects = DockBubble.regionRects(DockBubble.outline(280, 120, edge, 10, 26), edge === "bottom"
                                                 ? 130 : 120);
            verify(contains(rects, 140, 60));
            verify(!contains(rects, 0, 0));
            if (edge === "bottom") {
                verify(contains(rects, 26, 125));
                verify(!contains(rects, 140, 125));
            } else if (edge === "left") {
                verify(contains(rects, 4, 26));
                verify(!contains(rects, 4, 75));
            } else {
                verify(contains(rects, 275, 26));
                verify(!contains(rects, 275, 75));
            }
            for (const rect of rects) {
                verify(rect.x >= 0 && rect.y >= 0);
                verify(rect.width > 0 && rect.height > 0);
                verify(rect.x + rect.width <= 280);
                verify(rect.y + rect.height <= (edge === "bottom" ? 130 : 120));
            }
        }
    }

    function test_tailFollowsClampedAnchor() {
        const left = DockBubble.regionRects(DockBubble.outline(280, 120, "bottom", 10, -50), 130);
        const right = DockBubble.regionRects(DockBubble.outline(280, 120, "bottom", 10, 500), 130);
        verify(contains(left, 26, 125));
        verify(!contains(left, 254, 125));
        verify(contains(right, 254, 125));
        verify(!contains(right, 26, 125));
    }

    function test_previewHasNoTailAndHandlesEmptyGeometry() {
        const rects = DockBubble.regionRects(DockBubble.outline(280, 120, "bottom", 0, 26), 130);
        verify(contains(rects, 140, 118));
        verify(!contains(rects, 26, 125));
        compare(DockBubble.regionRects(DockBubble.outline(0, 0, "bottom", 10, 26), 0).length, 0);
    }
}
