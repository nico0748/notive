import NotesCore
import SwiftUI

/// iPadOS の右ペインのノートエディタ。
///
/// 本イテレーションでは編集を Markdown テキストで行い、プレビューでリッチ表示する
/// （F-EDIT-01／F-EDIT-02）。手書き（Apple Pencil）は後続イテレーションで対応する。
struct PadEditorView: View {
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

            tagBar.padding(.top, 6)

            HStack {
                Text(editor.saveState.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 2)

            Divider().padding(.vertical, 8)

            if editor.isMarkdownMode {
                TextEditor(text: $editor.markdownText)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .onChange(of: editor.markdownText) { _, _ in editor.scheduleAutosave() }
            } else {
                ScrollView {
                    PadBlockRenderer(blocks: editor.blocks)
                        .padding()
                }
            }
        }
    }

    private var tagBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(editor.assignedTags) { tag in
                    PadTagChip(tag: tag) { editor.toggleTag(tag.id) }
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
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if editor.note != nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    editor.toggleMarkdownMode()
                } label: {
                    Label(
                        editor.isMarkdownMode ? "プレビュー" : "編集",
                        systemImage: editor.isMarkdownMode ? "eye" : "pencil"
                    )
                }
            }
        }
    }
}

/// 付与済みタグを表すチップ（iPadOS）。タップで解除する。
private struct PadTagChip: View {
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
