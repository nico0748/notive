import NotesCore
import SwiftUI

/// 中央ペインのノート一覧（F-ORG-06 / F-SEARCH-01）。
struct NoteListView: View {
    @Bindable var noteList: NoteListViewModel
    let workspaceID: UUID

    var body: some View {
        List(selection: $noteList.selectedNoteID) {
            ForEach(noteList.displayedNotes) { note in
                NoteRow(note: note)
                    .tag(note.id)
                    .contextMenu { contextMenu(for: note) }
            }
        }
        .overlay {
            if noteList.displayedNotes.isEmpty {
                ContentUnavailableView(
                    noteList.isSearching ? "該当するノートがありません" : "ノートがありません",
                    systemImage: "note.text",
                    description: Text(noteList.isSearching ? "別のキーワードをお試しください。" : "右上の＋から作成できます。")
                )
            }
        }
        .searchable(text: $noteList.searchText, prompt: "タイトル・本文を検索")
        .navigationTitle("ノート")
        .toolbar {
            ToolbarItem {
                Menu {
                    Picker("並び順", selection: $noteList.sortOrder) {
                        ForEach(NoteSortOrder.allCases, id: \.self) { order in
                            Text(order.label).tag(order)
                        }
                    }
                } label: {
                    Label("並び順", systemImage: "arrow.up.arrow.down")
                }
            }
            ToolbarItem {
                Button {
                    Task { await noteList.createNote(workspaceID: workspaceID) }
                } label: {
                    Label("新規ノート", systemImage: "square.and.pencil")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for note: Note) -> some View {
        Button(note.isPinned ? "ピン留めを解除" : "ピン留め") {
            Task { await noteList.togglePin(note) }
        }
        Button(note.isFavorite ? "お気に入りから外す" : "お気に入りに追加") {
            Task { await noteList.toggleFavorite(note) }
        }
        Divider()
        if note.isTrashed {
            Button("復元") { Task { await noteList.restore(note) } }
            Button("完全に削除", role: .destructive) {
                Task { await noteList.deletePermanently(note) }
            }
        } else {
            Button("ゴミ箱に移動", role: .destructive) {
                Task { await noteList.moveToTrash(note) }
            }
        }
    }
}

/// ノート一覧の 1 行。
private struct NoteRow: View {
    let note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Text(note.title.isEmpty ? NotesConstants.Naming.untitledNote : note.title)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if note.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
            }
            Text(snippet)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var snippet: String {
        let text = note.blocks
            .map(\.plainText)
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return text ?? "（空のノート）"
    }
}
