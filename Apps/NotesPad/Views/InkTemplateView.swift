import NotesCore
import SwiftUI

/// 手書きブロックの背景テンプレートを描画するビュー（F-INK-12）。
///
/// 罫線・方眼・ドット・五線譜・コーネル式のパターンを `Canvas` で描く。
/// エディタではキャンバスの背面に、プレビューでは手書き画像の背面に重ねて使う。
struct InkTemplateView: View {
    let template: InkTemplate

    /// 罫線・方眼・ドットの間隔（ポイント）。
    private let spacing: CGFloat = 32

    var body: some View {
        Canvas { context, size in
            switch template {
            case .blank:
                break
            case .ruled:
                drawHorizontalLines(in: context, size: size, spacing: spacing)
            case .grid:
                drawHorizontalLines(in: context, size: size, spacing: spacing)
                drawVerticalLines(in: context, size: size, spacing: spacing)
            case .dots:
                drawDots(in: context, size: size, spacing: spacing)
            case .staff:
                drawStaff(in: context, size: size)
            case .cornell:
                drawCornell(in: context, size: size)
            }
        }
        .allowsHitTesting(false)
    }

    private var lineColor: GraphicsContext.Shading { .color(.secondary.opacity(0.35)) }
    private var accentColor: GraphicsContext.Shading { .color(.secondary.opacity(0.6)) }

    private func drawHorizontalLines(in context: GraphicsContext, size: CGSize, spacing: CGFloat) {
        var path = Path()
        var y = spacing
        while y < size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        context.stroke(path, with: lineColor, lineWidth: 1)
    }

    private func drawVerticalLines(in context: GraphicsContext, size: CGSize, spacing: CGFloat) {
        var path = Path()
        var x = spacing
        while x < size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }
        context.stroke(path, with: lineColor, lineWidth: 1)
    }

    private func drawDots(in context: GraphicsContext, size: CGSize, spacing: CGFloat) {
        var path = Path()
        var y = spacing
        while y < size.height {
            var x = spacing
            while x < size.width {
                path.addEllipse(in: CGRect(x: x - 1.2, y: y - 1.2, width: 2.4, height: 2.4))
                x += spacing
            }
            y += spacing
        }
        context.fill(path, with: lineColor)
    }

    private func drawStaff(in context: GraphicsContext, size: CGSize) {
        let lineGap: CGFloat = 9
        let groupGap: CGFloat = 36
        var path = Path()
        var top = groupGap
        while top + lineGap * 4 < size.height {
            for index in 0..<5 {
                let y = top + CGFloat(index) * lineGap
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
            top += lineGap * 4 + groupGap
        }
        context.stroke(path, with: lineColor, lineWidth: 1)
    }

    private func drawCornell(in context: GraphicsContext, size: CGSize) {
        let cueWidth = size.width * 0.3
        let summaryY = size.height * 0.78

        var notes = Path()
        var y = spacing
        while y < summaryY {
            notes.move(to: CGPoint(x: 0, y: y))
            notes.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }
        context.stroke(notes, with: lineColor, lineWidth: 1)

        var dividers = Path()
        dividers.move(to: CGPoint(x: cueWidth, y: 0))
        dividers.addLine(to: CGPoint(x: cueWidth, y: summaryY))
        dividers.move(to: CGPoint(x: 0, y: summaryY))
        dividers.addLine(to: CGPoint(x: size.width, y: summaryY))
        context.stroke(dividers, with: accentColor, lineWidth: 1.5)
    }
}
