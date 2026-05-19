import NotesCore
import PencilKit
import SwiftUI
import UIKit

/// 手書きブロックを 1 件編集するシート（iPadOS）。
///
/// 前景・背景の 2 レイヤー（F-INK-11）、背景テンプレート（F-INK-12）、
/// 直近ストロークの図形補正（F-INK-08）に対応する。投げ縄選択（F-INK-06）は
/// `PadInkCanvasView` のツールピッカーが標準で提供する。
struct PadInkEditorView: View {
    let editor: EditorViewModel
    let inkID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var foregroundData: Data
    @State private var backgroundData: Data
    @State private var template: InkTemplate
    @State private var activeLayer: Layer = .foreground
    private let height: Double

    /// 編集対象のレイヤー（F-INK-11、手書きを背景／前景に分離）。
    private enum Layer: String, CaseIterable, Identifiable {
        case background
        case foreground

        var id: String { rawValue }
        var displayName: String { self == .foreground ? "前景" : "背景" }
    }

    init(editor: EditorViewModel, inkID: UUID) {
        self.editor = editor
        self.inkID = inkID
        let ink = editor.inkBlock(id: inkID) ?? InkBlock(id: inkID)
        _foregroundData = State(initialValue: ink.drawingData)
        _backgroundData = State(initialValue: ink.backgroundData)
        _template = State(initialValue: ink.template)
        height = ink.height
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .secondarySystemBackground)
                InkTemplateView(template: template)
                // 編集していない側のレイヤーを薄く重ねて位置合わせの参考にする。
                if activeLayer == .foreground {
                    InkLayerBackdrop(data: backgroundData)
                }
                PadInkCanvasView(drawingData: activeBinding)
                    .id(activeLayer)
                if activeLayer == .background {
                    InkLayerBackdrop(data: foregroundData)
                }
            }
            .navigationTitle("手書き")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    private var activeBinding: Binding<Data> {
        switch activeLayer {
        case .foreground: return $foregroundData
        case .background: return $backgroundData
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("閉じる") { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            Picker("レイヤー", selection: $activeLayer) {
                ForEach(Layer.allCases) { layer in
                    Text(layer.displayName).tag(layer)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 180)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Picker("テンプレート", selection: $template) {
                    ForEach(InkTemplate.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
            } label: {
                Label("テンプレート", systemImage: "square.grid.2x2")
            }
            Button {
                correctLastStroke()
            } label: {
                Label("図形補正", systemImage: "scribble.variable")
            }
            Button("完了") { save() }
        }
    }

    /// 編集中レイヤーの最後のストロークを整形図形へ補正する（F-INK-08）。
    private func correctLastStroke() {
        switch activeLayer {
        case .foreground:
            if let corrected = InkShapeCorrection.correctingLastStroke(in: foregroundData) {
                foregroundData = corrected
            }
        case .background:
            if let corrected = InkShapeCorrection.correctingLastStroke(in: backgroundData) {
                backgroundData = corrected
            }
        }
    }

    private func save() {
        editor.updateInkBlock(
            InkBlock(id: inkID,
                     drawingData: foregroundData,
                     backgroundData: backgroundData,
                     template: template,
                     height: height)
        )
        dismiss()
    }
}

/// 編集していないレイヤーを薄く表示する参照用の背面ビュー。
private struct InkLayerBackdrop: View {
    let data: Data

    var body: some View {
        GeometryReader { proxy in
            if let image = Self.image(of: data, size: proxy.size) {
                Image(uiImage: image)
                    .opacity(0.35)
                    .allowsHitTesting(false)
            }
        }
    }

    private static func image(of data: Data, size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0,
              let drawing = try? PKDrawing(data: data),
              !drawing.bounds.isEmpty else { return nil }
        return drawing.image(from: CGRect(origin: .zero, size: size), scale: 2.0)
    }
}
