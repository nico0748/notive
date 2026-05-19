import CoreGraphics
import Foundation

/// 手書きストロークから認識した整形図形（F-INK-08、図形補正）。
public enum RecognizedShape: Equatable, Sendable {
    /// 直線。始点と終点を結ぶ。
    case line(from: CGPoint, to: CGPoint)
    /// 軸並行の矩形。
    case rectangle(CGRect)
    /// 矩形に内接する楕円。
    case ellipse(in: CGRect)
}

/// 手書きストロークの点列を直線・矩形・楕円へ分類する図形補正エンジン（F-INK-08）。
///
/// PencilKit 非依存の純粋な幾何計算として `NotesCore` に置き、ユニットテスト可能にする。
/// iPadOS 側はストロークの補間点列を渡し、結果の理想図形で `PKStroke` を再構成する。
public enum StrokeShapeRecognizer {

    /// 分類に必要な最小点数。
    private static let minimumPoints = 8
    /// 認識対象とみなす最小の外接矩形対角長（ポイント）。
    private static let minimumSize: CGFloat = 24
    /// 始点・終点の距離が対角長に対しこの比率以下なら閉じた経路とみなす。
    private static let closedGapRatio: CGFloat = 0.25
    /// 直線とみなす、始終点を結ぶ線からの最大ずれ（対角長比）。
    private static let straightTolerance: CGFloat = 0.12
    /// 矩形・楕円とみなす、理想形からの平均ずれ（対角長比）。
    private static let closedShapeTolerance: CGFloat = 0.22

    /// 点列を図形へ分類する。分類できない場合は `nil`。
    public static func recognize(_ points: [CGPoint]) -> RecognizedShape? {
        guard points.count >= minimumPoints,
              let start = points.first,
              let end = points.last else { return nil }

        let box = boundingBox(of: points)
        let diagonal = hypot(box.width, box.height)
        guard diagonal >= minimumSize else { return nil }

        let isClosed = distance(start, end) <= diagonal * closedGapRatio

        if !isClosed {
            if straightness(of: points) <= diagonal * straightTolerance {
                return .line(from: start, to: end)
            }
            return nil
        }

        // 閉じた経路は矩形か楕円のどちらに近いかで判定する。
        guard box.width >= minimumSize * 0.25, box.height >= minimumSize * 0.25 else {
            return nil
        }
        let rectError = rectangleFitError(of: points, box: box)
        let ellipseError = ellipseFitError(of: points, box: box)
        guard min(rectError, ellipseError) <= diagonal * closedShapeTolerance else {
            return nil
        }
        return rectError <= ellipseError ? .rectangle(box) : .ellipse(in: box)
    }

    // MARK: - 幾何ヘルパー

    private static func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private static func boundingBox(of points: [CGPoint]) -> CGRect {
        var minX = points[0].x, maxX = points[0].x
        var minY = points[0].y, maxY = points[0].y
        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// 始点と終点を結ぶ直線からの最大垂直距離。
    private static func straightness(of points: [CGPoint]) -> CGFloat {
        guard let start = points.first, let end = points.last else { return 0 }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = hypot(dx, dy)
        guard length > 0 else { return 0 }
        var maxDistance: CGFloat = 0
        for point in points {
            let deviation = abs(dy * (point.x - start.x) - dx * (point.y - start.y)) / length
            maxDistance = max(maxDistance, deviation)
        }
        return maxDistance
    }

    /// 各点から外接矩形の周への距離の平均。
    private static func rectangleFitError(of points: [CGPoint], box: CGRect) -> CGFloat {
        var total: CGFloat = 0
        for point in points {
            if box.contains(point) {
                total += min(point.x - box.minX, box.maxX - point.x,
                             point.y - box.minY, box.maxY - point.y)
            } else {
                let nearestX = min(max(point.x, box.minX), box.maxX)
                let nearestY = min(max(point.y, box.minY), box.maxY)
                total += hypot(point.x - nearestX, point.y - nearestY)
            }
        }
        return total / CGFloat(points.count)
    }

    /// 各点から外接矩形に内接する楕円への距離（近似）の平均。
    private static func ellipseFitError(of points: [CGPoint], box: CGRect) -> CGFloat {
        let radiusX = box.width / 2
        let radiusY = box.height / 2
        guard radiusX > 0, radiusY > 0 else { return .greatestFiniteMagnitude }
        let center = CGPoint(x: box.midX, y: box.midY)
        let scale = min(radiusX, radiusY)
        var total: CGFloat = 0
        for point in points {
            let normalizedX = (point.x - center.x) / radiusX
            let normalizedY = (point.y - center.y) / radiusY
            let radius = sqrt(normalizedX * normalizedX + normalizedY * normalizedY)
            total += abs(radius - 1) * scale
        }
        return total / CGFloat(points.count)
    }
}
