import NotesCore
import SwiftUI
import UIKit

/// 手書きブロックを 1 件編集するシート（iPadOS）。
struct PadInkEditorView: View {
    let editor: EditorViewModel
    let inkID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var drawingData: Data

    init(editor: EditorViewModel, inkID: UUID) {
        self.editor = editor
        self.inkID = inkID
        _drawingData = State(initialValue: editor.inkBlock(id: inkID)?.drawingData ?? Data())
    }

    var body: some View {
        NavigationStack {
            PadInkCanvasView(drawingData: $drawingData)
                .background(Color(uiColor: .secondarySystemBackground))
                .navigationTitle("手書き")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了") {
                            editor.updateInkBlock(id: inkID, drawingData: drawingData)
                            dismiss()
                        }
                    }
                }
        }
    }
}
