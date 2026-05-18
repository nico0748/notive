import NotesCore
import SwiftUI

/// 右ペインのノートエディタ（F-EDIT-01〜07）。
struct EditorView: View {
    @Bindable var editor: EditorViewModel

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
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("タイトル", text: $editor.title)
                .textFieldStyle(.plain)
                .font(.largeTitle.bold())
                .padding(.horizontal)
                .padding(.top)
                .onChange(of: editor.title) { _, _ in editor.scheduleAutosave() }

            Divider().padding(.vertical, 8)

            if editor.isMarkdownMode {
                markdownEditor
            } else {
                BlockListView(editor: editor)
            }
        }
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
