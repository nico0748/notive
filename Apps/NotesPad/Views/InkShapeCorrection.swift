import CoreGraphics
import Foundation
import NotesCore
import PencilKit

/// 手書きストロークを `StrokeShapeRecognizer` で整形図形へ補正する（F-INK-08）。
///
/// 認識（直線・矩形・楕円の分類）は PencilKit 非依存の `NotesCore` 側に置き、
/// ここでは `PKDrawing` ⇄ 点列の変換と、整形図形をなぞる `PKStroke` の再構成を担う。
enum InkShapeCorrection {

    /// 描画データの最後のストロークを認識し、整形図形へ置き換えた描画データを返す。
    /// ストロークが無い、または図形として認識できない場合は `nil`。
    static func correctingLastStroke(in data: Data) -> Data? {
        guard let drawing = try? PKDrawing(data: data),
              let last = drawing.strokes.last else { return nil }

        let points = sampledPoints(of: last)
        guard let shape = StrokeShapeRecognizer.recognize(points) else { return nil }

        var strokes = drawing.strokes
        strokes[strokes.count - 1] = idealStroke(for: shape, like: last)
        return PKDrawing(strokes: strokes).dataRepresentation()
    }

    /// ストロークの描画空間における補間点列を取得する。
    private static func sampledPoints(of stroke: PKStroke) -> [CGPoint] {
        stroke.path.interpolatedPoints(by: .distance(4)).map { point in
            point.location.applying(stroke.transform)
        }
    }

    /// 認識した図形をなぞる点列を生成する。
    private static func tracePoints(for shape: RecognizedShape) -> [CGPoint] {
        switch shape {
        case .line(let from, let to):
            return interpolate(from: from, to: to, count: 24)
        case .rectangle(let rect):
            let corners = [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.maxY),
                CGPoint(x: rect.minX, y: rect.maxY)
            ]
            var points: [CGPoint] = []
            for index in 0..<corners.count {
                let edge = interpolate(from: corners[index],
                                       to: corners[(index + 1) % corners.count],
                                       count: 16)
                points.append(contentsOf: edge.dropLast())
            }
            points.append(corners[0])
            return points
        case .ellipse(let rect):
            let radiusX = rect.width / 2
            let radiusY = rect.height / 2
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let steps = 64
            return (0...steps).map { step in
                let angle = CGFloat(step) / CGFloat(steps) * 2 * .pi
                return CGPoint(x: center.x + radiusX * cos(angle),
                               y: center.y + radiusY * sin(angle))
            }
        }
    }

    private static func interpolate(from: CGPoint, to: CGPoint, count: Int) -> [CGPoint] {
        (0...count).map { step in
            let ratio = CGFloat(step) / CGFloat(count)
            return CGPoint(x: from.x + (to.x - from.x) * ratio,
                           y: from.y + (to.y - from.y) * ratio)
        }
    }

    /// 認識した図形を、元のストロークの筆致（インク・太さ）でなぞる新しいストロークを作る。
    private static func idealStroke(for shape: RecognizedShape, like original: PKStroke) -> PKStroke {
        let reference = original.path.first
        let size = reference?.size ?? CGSize(width: 4, height: 4)
        let force = reference?.force ?? 1
        let points = tracePoints(for: shape).enumerated().map { index, location in
            PKStrokePoint(location: location,
                          timeOffset: TimeInterval(index) * 0.01,
                          size: size,
                          opacity: 1,
                          force: force,
                          azimuth: 0,
                          altitude: .pi / 2)
        }
        let path = PKStrokePath(controlPoints: points, creationDate: Date())
        return PKStroke(ink: original.ink, path: path)
    }
}
