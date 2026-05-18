import NotesCore
import SwiftUI

/// 右ペインのノートエディタ（F-EDIT-01〜07、F-ORG-03 タグ付与）。
struct EditorView: View {
    @Bindable var editor: EditorViewModel

    @State private var isCreatingTag = false
    @State private var newTagName = ""

    var body: some View {
        Group {
            if editor.note == nil {
                ContentUnavailableView(
                    "ノートが選択されていません",
                    systemImage: "doc.text",
                    description: Text("一覧からノートを選択するか、新規作成してください。")
                )
            } else {
                editorBody
            }
        }
        .toolbar { toolbarContent }
        .alert("新しいタグ", isPresented: $isCreatingTag) {
            TextField("タグ名", text: $newTagName)
            Button("作成") {
                let name = newTagName
                newTagName = ""
                Task { await editor.createAndAssignTag(named: name) }
            }
            Button("キャンセル", role: .cancel) { newTagName = "" }
        }
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("タイトル", text: $editor.title)
                .textFieldStyle(.plain)
                .font(.largeTitle.bold())
                .padding(.horizontal)
                .padding(.top)
                .onChange(of: editor.title) { _, _ in editor.scheduleAutosave() }

            tagBar
                .padding(.top, 6)

            Divider().padding(.vertical, 8)

            if editor.isMarkdownMode {
                markdownEditor
            } else {
                BlockListView(editor: editor)
            }
        }
    }

    /// タグの表示・付与・解除を行うバー（F-ORG-03）。
    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(editor.assignedTags) { tag in
                    TagChip(tag: tag) { editor.toggleTag(tag.id) }
                }
                tagMenu
            }
            .padding(.horizontal)
        }
    }

    private var tagMenu: some View {
        Menu {
            ForEach(editor.unassignedTags) { tag in
                Button {
                    editor.toggleTag(tag.id)
                } label: {
                    Label(tag.name, systemImage: "tag")
                }
            }
            if !editor.unassignedTags.isEmpty {
                Divider()
            }
            Button("新しいタグを作成…") { isCreatingTag = true }
        } label: {
            Label("タグを追加", systemImage: "tag")
                .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private var markdownEditor: some View {
        TextEditor(text: $editor.markdownText)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 12)
            .onChange(of: editor.markdownText) { _, _ in editor.scheduleAutosave() }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if editor.note != nil {
            ToolbarItem(placement: .status) {
                Text(editor.saveState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ToolbarItem {
                Button {
                    editor.toggleMarkdownMode()
                } label: {
                    Label(
                        editor.isMarkdownMode ? "リッチ表示" : "Markdown",
                        systemImage: editor.isMarkdownMode ? "doc.richtext" : "chevron.left.forwardslash.chevron.right"
                    )
                }
                .help("Markdown 入力とリッチ表示を切り替えます")
            }
            if !editor.isMarkdownMode {
                ToolbarItem {
                    addBlockMenu
                }
            }
        }
    }

    private var addBlockMenu: some View {
        Menu {
            Button("見出し") { editor.appendBlock(.heading(HeadingBlock())) }
            Button("段落") { editor.appendBlock(.paragraph(ParagraphBlock())) }
            Button("箇条書きリスト") { editor.appendBlock(.bulletedList(ListBlock())) }
            Button("番号付きリスト") { editor.appendBlock(.numberedList(ListBlock())) }
            Button("引用") { editor.appendBlock(.quote(QuoteBlock())) }
            Button("コードブロック") { editor.appendBlock(.code(CodeBlock())) }
            Button("チェックリスト") { editor.appendBlock(.checklist(ChecklistBlock())) }
            Button("テーブル") { editor.appendBlock(.table(TableBlock.makeDefault())) }
        } label: {
            Label("ブロックを追加", systemImage: "plus")
        }
    }
}

/// 付与済みタグを表すチップ。タップで解除する。
private struct TagChip: View {
    let tag: Tag
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 8, height: 8)
            Text(tag.name)
                .font(.caption)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color(hex: tag.colorHex).opacity(0.15), in: Capsule())
    }
}
