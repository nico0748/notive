import NotesCore
import SwiftUI

/// iPadOS のメイン画面。サイドバー・ノート一覧・エディタの 3 カラム構成（要件 7-3、適応レイアウト）。
struct PadMainView: View {
    private let appModel: AppViewModel
    @State private var sidebar: SidebarViewModel
    @State private var noteList: NoteListViewModel
    @State private var editor: EditorViewModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(appModel: AppViewModel) {
        self.appModel = appModel
        _sidebar = State(initialValue: SidebarViewModel(folderService: appModel.folderService))
        _noteList = State(initialValue: NoteListViewModel(
            noteService: appModel.noteService,
            searchService: appModel.searchService
        ))
        _editor = State(initialValue: EditorViewModel(
            noteService: appModel.noteService,
            tagService: appModel.tagService
        ))
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            PadSidebarView(sidebar: sidebar)
        } content: {
            PadNoteListView(noteList: noteList, workspaceID: workspaceID)
        } detail: {
            PadEditorView(editor: editor)
        }
        .navigationSplitViewStyle(.balanced)
        .task { await initialLoad() }
        .onChange(of: sidebar.selection) { _, newValue in
            Task { await noteList.load(workspaceID: workspaceID, selection: newValue) }
        }
        .onChange(of: noteList.searchText) { _, _ in
            Task { await noteList.reload() }
        }
        .onChange(of: noteList.selectedNoteID) { _, newValue in
            Task { await openSelectedNote(id: newValue) }
        }
        .onChange(of: editor.saveState) { _, newValue in
            if newValue == .saved {
                Task { await noteList.reload() }
            }
        }
    }

    private var workspaceID: UUID {
        appModel.currentWorkspace?.id ?? UUID()
    }

    private func initialLoad() async {
        guard let workspace = appModel.currentWorkspace else { return }
        await sidebar.load(workspaceID: workspace.id)
        await noteList.load(workspaceID: workspace.id, selection: sidebar.selection)
    }

    private func openSelectedNote(id: UUID?) async {
        if let id, let note = noteList.notes.first(where: { $0.id == id }) {
            await editor.open(note)
        } else {
            await editor.close()
        }
    }
}
