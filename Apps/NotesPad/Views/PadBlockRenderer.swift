import NotesCore
import PencilKit
import SwiftUI
import UIKit

/// ノート本文（ブロック配列）を描画する（iPadOS のプレビュー表示）。
///
/// テキスト系ブロックは読み取り専用、手書きブロックはタップで編集シートを開く。
struct PadBlockRenderer: View {
    let blocks: [Block]
    /// 手書きブロックがタップされたときに、その識別子を通知する。
    var onTapInk: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(blocks) { block in
                view(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private func view(for block: Block) -> some View {
        switch block {
        case .heading(let heading):
            Text(heading.text)
                .font(headingFont(level: heading.level))
                .bold()
        case .paragraph(let paragraph):
            Text(LocalizedStringKey(paragraph.text))
                .font(.body)
        case .bulletedList(let list):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(list.items.enumerated()), id: \.offset) { _, item in
                    Label(item, systemImage: "circle.fill")
                        .labelStyle(BulletLabelStyle())
                }
            }
        case .numberedList(let list):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(list.items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).").foregroundStyle(.secondary)
                        Text(item)
                    }
                }
            }
        case .quote(let quote):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2).fill(.secondary).frame(width: 3)
                Text(quote.text).font(.body.italic()).foregroundStyle(.secondary)
            }
        case .code(let code):
            Text(code.code)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        case .checklist(let checklist):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(checklist.items) { item in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: item.isDone ? "checkmark.square.fill" : "square")
                            .foregroundStyle(item.isDone ? Color.accentColor : .secondary)
                        Text(item.text)
                            .strikethrough(item.isDone)
                            .foregroundStyle(item.isDone ? .secondary : .primary)
                    }
                }
            }
        case .table(let table):
            tableView(table)
        case .image(let image):
            Label(image.caption.isEmpty ? "画像" : image.caption, systemImage: "photo")
                .foregroundStyle(.secondary)
        case .ink(let ink):
            inkView(ink)
        }
    }

    private func inkView(_ ink: InkBlock) -> some View {
        Button {
            onTapInk(ink.id)
        } label: {
            Group {
                if let image = Self.renderedImage(for: ink) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "scribble.variable")
                        Text("手書き（タップして描く）")
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    /// 手書きブロックの描画を画像へレンダリングする。未描画なら `nil`。
    static func renderedImage(for ink: InkBlock) -> UIImage? {
        guard !ink.isEmpty, let drawing = try? PKDrawing(data: ink.drawingData) else { return nil }
        let bounds = drawing.bounds
        guard !bounds.isEmpty, bounds.width.isFinite, bounds.height.isFinite else { return nil }
        return drawing.image(from: bounds, scale: 2.0)
    }

    private func tableView(_ table: TableBlock) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 4) {
            GridRow {
                ForEach(Array(table.headers.enumerated()), id: \.offset) { _, header in
                    Text(header).bold()
                }
            }
            Divider()
            ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                        Text(cell)
                    }
                }
            }
        }
    }

    private func headingFont(level: Int) -> Font {
        switch level {
        case 1: return .title
        case 2: return .title2
        default: return .title3
        }
    }
}

/// 箇条書きの小さな中黒マーカー。
private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 8) {
            configuration.icon
                .font(.system(size: 5))
                .foregroundStyle(.secondary)
                .padding(.top, 7)
            configuration.title
        }
    }
}
