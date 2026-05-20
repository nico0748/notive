import NotesCore
import SwiftUI

/// リッチ表示モードのブロック編集領域（F-EDIT-01）。
struct BlockListView: View {
    @Bindable var editor: EditorViewModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach($editor.blocks) { $block in
                    BlockEditorRow(
                        block: $block,
                        onDelete: { editor.removeBlock(id: block.id) },
                        onAddBelow: { newBlock in editor.insertBlock(newBlock, after: block.id) }
                    )
                }
            }
            .padding()
        }
        .onChange(of: editor.blocks) { _, _ in editor.scheduleAutosave() }
    }
}

/// ブロック 1 件を、その種別に応じた編集ビューへ振り分ける行。
struct BlockEditorRow: View {
    @Binding var block: Block
    let onDelete: () -> Void
    let onAddBelow: (Block) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            blockContent
                .frame(maxWidth: .infinity, alignment: .leading)
            blockMenu
        }
    }

    @ViewBuilder
    private var blockContent: some View {
        switch block {
        case .heading:
            if let binding = $block.headingBinding { HeadingBlockEditor(block: binding) }
        case .paragraph:
            if let binding = $block.paragraphBinding { ParagraphBlockEditor(block: binding) }
        case .bulletedList:
            if let binding = $block.listBinding { ListBlockEditor(block: binding, ordered: false) }
        case .numberedList:
            if let binding = $block.listBinding { ListBlockEditor(block: binding, ordered: true) }
        case .quote:
            if let binding = $block.quoteBinding { QuoteBlockEditor(block: binding) }
        case .code:
            if let binding = $block.codeBinding { CodeBlockEditor(block: binding) }
        case .checklist:
            if let binding = $block.checklistBinding { ChecklistBlockEditor(block: binding) }
        case .table:
            if let binding = $block.tableBinding { TableBlockEditor(block: binding) }
        case .image:
            if let binding = $block.imageBinding { ImageBlockEditor(block: binding) }
        case .ink(let ink):
            InkPlaceholderView(ink: ink)
        case .pdf(let pdf):
            MacPdfCard(pdf: pdf)
        }
    }

    private var blockMenu: some View {
        Menu {
            Button("下に段落を追加") { onAddBelow(.paragraph(ParagraphBlock())) }
            Button("下に見出しを追加") { onAddBelow(.heading(HeadingBlock())) }
            Divider()
            Button("削除", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// 手書きブロックの macOS 向けプレースホルダ表示。
///
/// 手書きの作成・編集は iPad（Apple Pencil）で行う。macOS のトラックパッド描画
/// （F-INK-15）は後続イテレーションで対応するため、ここでは存在のみを示す。
struct InkPlaceholderView: View {
    let ink: InkBlock

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "scribble.variable")
                .foregroundStyle(.tint)
            Text(ink.isEmpty ? "手書きブロック（未描画）" : "手書きブロック")
                .foregroundStyle(.secondary)
            if ink.template != .blank {
                Text(ink.template.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            Spacer()
            Text("iPad で編集")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
