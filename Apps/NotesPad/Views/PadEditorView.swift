import NotesCore
import SwiftUI
import UniformTypeIdentifiers

/// iPadOS の右ペインのノートエディタ。
///
/// テキストは Markdown 編集とリッチプレビューを切り替え（F-EDIT-01／F-EDIT-02）、
/// 手書きブロックはプレビュー上のキャンバスシートで編集する（F-INK-13）。
/// PDF はツールバーから読み込んでノート内に埋め込む（F-PDF-01／F-PDF-02）。
struct PadEditorView: View {
    @Bindable var editor: EditorViewModel

    @State private var isCreatingTag = false
    @State private var newTagName = ""
    @State private var inkEditTarget: InkEditTarget?
    @State private var isImportingPdf = false
    @State private var isShowingVersionHistory = false

    /// 手書き編集シートの対象。`.sheet(item:)` で扱うため `Identifiable` でラップする。
    private struct InkEditTarget: Identifiable {
        let id: UUID
    }

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
        .sheet(item: $inkEditTarget) { target in
            PadInkEditorView(editor: editor, inkID: target.id)
        }
        .fileImporter(isPresented: $isImportingPdf, allowedContentTypes: [.pdf]) { result in
            if case .success(let url) = result, let block = PdfImport.makeBlock(from: url) {
                editor.appendPdfBlock(block)
            }
        }
        .sheet(isPresented: $isShowingVersionHistory) {
            PadVersionHistoryView(editor: editor)
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
                    PadBlockRenderer(blocks: editor.blocks) { inkID in
                        inkEditTarget = InkEditTarget(id: inkID)
                    }
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
            if !editor.isMarkdownMode {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        inkEditTarget = InkEditTarget(id: editor.addInkBlock())
                    } label: {
                        Label("手書きを追加", systemImage: "scribble.variable")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isImportingPdf = true
                    } label: {
                        Label("PDF を追加", systemImage: "doc.badge.plus")
                    }
                }
            }
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingVersionHistory = true
                } label: {
                    Label("履歴", systemImage: "clock.arrow.circlepath")
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
