import PencilKit
import SwiftUI
import UIKit

/// PencilKit の `PKCanvasView` を SwiftUI でラップした手書きキャンバス（iPadOS）。
///
/// 描画内容は `PKDrawing.dataRepresentation()` のバイト列として `drawingData` に
/// 双方向バインドする（要件定義書 §11.2 の設計判断: Apple ネイティブ形式を採用）。
struct PadInkCanvasView: UIViewRepresentable {
    @Binding var drawingData: Data

    func makeCoordinator() -> Coordinator {
        Coordinator(drawingData: $drawingData)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        // 指・Apple Pencil・トラックパッドのいずれでも描画できるようにする（F-INK-01）。
        canvas.drawingPolicy = .anyInput
        canvas.alwaysBounceVertical = true
        canvas.backgroundColor = .clear
        if let drawing = try? PKDrawing(data: drawingData) {
            canvas.drawing = drawing
        }

        // ペン・マーカー・消しゴム・色（F-INK-04 / F-INK-05）、および投げ縄選択による
        // 移動・複製・削除（F-INK-06）はツールピッカーが標準で提供する。
        let toolPicker = context.coordinator.toolPicker
        toolPicker.setVisible(true, forFirstResponder: canvas)
        toolPicker.addObserver(canvas)
        DispatchQueue.main.async { canvas.becomeFirstResponder() }
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        guard let drawing = try? PKDrawing(data: drawingData) else { return }
        if canvas.drawing.dataRepresentation() != drawingData {
            canvas.drawing = drawing
        }
    }

    /// 描画変更を `drawingData` バインディングへ反映するコーディネータ。
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        private let drawingData: Binding<Data>
        let toolPicker = PKToolPicker()

        init(drawingData: Binding<Data>) {
            self.drawingData = drawingData
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawingData.wrappedValue = canvasView.drawing.dataRepresentation()
        }
    }
}
