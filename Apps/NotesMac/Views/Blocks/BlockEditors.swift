import NotesCore
import SwiftUI

/// 見出しブロックの編集ビュー（F-EDIT-01）。
struct HeadingBlockEditor: View {
    @Binding var block: HeadingBlock

    var body: some View {
        HStack(spacing: 8) {
            Picker("見出しレベル", selection: $block.level) {
                ForEach(NotesConstants.Heading.minLevel...NotesConstants.Heading.maxLevel, id: \.self) { level in
                    Text("H\(level)").tag(level)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            TextField("見出し", text: $block.text)
                .textFieldStyle(.plain)
                .font(headingFont)
        }
    }

    private var headingFont: Font {
        switch block.level {
        case 1: return .title.bold()
        case 2: return .title2.bold()
        default: return .title3.bold()
        }
    }
}

/// 段落ブロックの編集ビュー（F-EDIT-01。`**bold**` などのインライン Markdown を許容）。
struct ParagraphBlockEditor: View {
    @Binding var block: ParagraphBlock

    var body: some View {
        TextField("本文を入力", text: $block.text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.body)
    }
}

/// 引用ブロックの編集ビュー（F-EDIT-01）。
struct QuoteBlockEditor: View {
    @Binding var block: QuoteBlock

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(.secondary)
                .frame(width: 3)
            TextField("引用", text: $block.text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body.italic())
                .foregroundStyle(.secondary)
        }
    }
}

/// 箇条書き／番号付きリストの編集ビュー（F-EDIT-01）。
struct ListBlockEditor: View {
    @Binding var block: ListBlock
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(block.items.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 6) {
                    Text(ordered ? "\(index + 1)." : "•")
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    TextField("項目", text: $block.items[index], axis: .vertical)
                        .textFieldStyle(.plain)
                    if block.items.count > 1 {
                        Button {
                            block.items.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            Button {
                block.items.append("")
            } label: {
                Label("項目を追加", systemImage: "plus").font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}

/// チェックリストの編集ビュー（F-EDIT-05）。
struct ChecklistBlockEditor: View {
    @Binding var block: ChecklistBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($block.items) { $item in
                HStack(alignment: .top, spacing: 6) {
                    Toggle("完了", isOn: $item.isDone)
                        .labelsHidden()
                        .toggleStyle(.checkbox)
                    TextField("タスク", text: $item.text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .strikethrough(item.isDone)
                        .foregroundStyle(item.isDone ? .secondary : .primary)
                    if block.items.count > 1 {
                        Button {
                            block.items.removeAll { $0.id == item.id }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.tertiary)
                    }
                }
            }
            Button {
                block.items.append(ChecklistItem())
            } label: {
                Label("タスクを追加", systemImage: "plus").font(.caption)
            }
            .buttonStyle(.borderless)
        }
    }
}

/// テーブルの編集ビュー（F-EDIT-06。最小実装：行列追加とセル編集）。
struct TableBlockEditor: View {
    @Binding var block: TableBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 4) {
                GridRow {
                    ForEach(block.headers.indices, id: \.self) { column in
                        TextField("見出し", text: $block.headers[column])
                            .textFieldStyle(.roundedBorder)
                            .fontWeight(.semibold)
                    }
                }
                ForEach(block.rows.indices, id: \.self) { row in
                    GridRow {
                        ForEach(block.rows[row].indices, id: \.self) { column in
                            TextField("", text: $block.rows[row][column])
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                }
            }
            HStack(spacing: 12) {
                Button { addRow() } label: { Label("行を追加", systemImage: "plus") }
                Button { addColumn() } label: { Label("列を追加", systemImage: "plus") }
            }
            .font(.caption)
            .buttonStyle(.borderless)
        }
    }

    private func addRow() {
        block.rows.append(Array(repeating: "", count: block.columnCount))
    }

    private func addColumn() {
        block.headers.append("")
        for index in block.rows.indices {
            block.rows[index].append("")
        }
    }
}

/// 画像ブロックのプレースホルダ編集ビュー。
///
/// 画像添付の本格実装（F-EDIT-03 のドラッグ＆ドロップ等）は後続イテレーションで対応する。
struct ImageBlockEditor: View {
    @Binding var block: ImageBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: 120)
                .overlay {
                    // TODO: 画像添付（F-EDIT-03）を後続イテレーションで実装する。
                    Label("画像（後続イテレーションで対応）", systemImage: "photo")
                        .foregroundStyle(.secondary)
                }
            TextField("キャプション", text: $block.caption)
                .textFieldStyle(.plain)
                .font(.caption)
        }
    }
}
