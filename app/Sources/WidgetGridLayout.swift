import CoreGraphics

struct WidgetGridItemFrame: Equatable {
    let index: Int
    let frame: CGRect
}

enum WidgetGridLayout {
    static let coordinateSpaceName = "todayWidgetGrid"

    static func targetIndex(at location: CGPoint, in itemFrames: [WidgetGridItemFrame]) -> Int? {
        let sorted = itemFrames.sorted { $0.index < $1.index }
        guard !sorted.isEmpty else { return nil }

        if let containing = sorted.first(where: { $0.frame.contains(location) }) {
            return containing.index
        }

        if let rowEdgeTarget = targetIndexAtRowEdge(location, in: sorted) {
            return rowEdgeTarget
        }

        return sorted.min { lhs, rhs in
            squaredDistance(from: location, to: lhs.frame.center)
                < squaredDistance(from: location, to: rhs.frame.center)
        }?.index
    }

    static func reorder<T>(_ items: [T], movingFrom source: Int, to target: Int) -> [T] {
        guard items.indices.contains(source),
              items.indices.contains(target),
              source != target else { return items }

        var result = items
        let moved = result.remove(at: source)
        result.insert(moved, at: target)
        return result
    }

    private static func targetIndexAtRowEdge(
        _ location: CGPoint,
        in sortedFrames: [WidgetGridItemFrame]
    ) -> Int? {
        let rowFrames = sortedFrames.filter {
            location.y >= $0.frame.minY && location.y <= $0.frame.maxY
        }
        guard let first = rowFrames.first, let last = rowFrames.last else { return nil }

        if location.x < first.frame.minX { return first.index }
        if location.x > last.frame.maxX { return last.index }
        return nil
    }

    private static func squaredDistance(from point: CGPoint, to other: CGPoint) -> CGFloat {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return dx * dx + dy * dy
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
