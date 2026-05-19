import CoreGraphics
import XCTest
@testable import NotesCore

final class StrokeShapeRecognizerTests: XCTestCase {

    func testRecognizesStraightLine() {
        let points = (0...20).map { CGPoint(x: CGFloat($0) * 10, y: 0) }
        guard case .line(let from, let to)? = StrokeShapeRecognizer.recognize(points) else {
            return XCTFail("直線として認識されなかった")
        }
        XCTAssertEqual(from.x, 0, accuracy: 0.001)
        XCTAssertEqual(to.x, 200, accuracy: 0.001)
    }

    func testRecognizesRectangle() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 120)
        guard case .rectangle(let box)? = StrokeShapeRecognizer.recognize(Self.rectanglePath(rect)) else {
            return XCTFail("矩形として認識されなかった")
        }
        XCTAssertEqual(box.width, 200, accuracy: 1)
        XCTAssertEqual(box.height, 120, accuracy: 1)
    }

    func testRecognizesEllipse() {
        let rect = CGRect(x: 10, y: 10, width: 200, height: 140)
        guard case .ellipse(let box)? = StrokeShapeRecognizer.recognize(Self.ellipsePath(in: rect)) else {
            return XCTFail("楕円として認識されなかった")
        }
        XCTAssertEqual(box.width, 200, accuracy: 2)
        XCTAssertEqual(box.height, 140, accuracy: 2)
    }

    func testRejectsScribble() {
        let zigzag = (0...10).map { index -> CGPoint in
            CGPoint(x: CGFloat(index) * 20, y: index.isMultiple(of: 2) ? 0 : 90)
        }
        XCTAssertNil(StrokeShapeRecognizer.recognize(zigzag))
    }

    func testRejectsTooFewPoints() {
        XCTAssertNil(StrokeShapeRecognizer.recognize([.zero, CGPoint(x: 10, y: 0)]))
    }

    func testRejectsTinyStroke() {
        let points = (0...12).map { CGPoint(x: CGFloat($0), y: 0) }
        XCTAssertNil(StrokeShapeRecognizer.recognize(points))
    }

    // MARK: - 経路生成ヘルパー

    private static func rectanglePath(_ rect: CGRect) -> [CGPoint] {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        var points: [CGPoint] = []
        for index in 0..<corners.count {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            for step in 0..<12 {
                let ratio = CGFloat(step) / 12
                points.append(CGPoint(x: start.x + (end.x - start.x) * ratio,
                                      y: start.y + (end.y - start.y) * ratio))
            }
        }
        points.append(corners[0])
        return points
    }

    private static func ellipsePath(in rect: CGRect) -> [CGPoint] {
        let radiusX = rect.width / 2
        let radiusY = rect.height / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return (0...48).map { step in
            let angle = CGFloat(step) / 48 * 2 * .pi
            return CGPoint(x: center.x + radiusX * cos(angle),
                           y: center.y + radiusY * sin(angle))
        }
    }
}
