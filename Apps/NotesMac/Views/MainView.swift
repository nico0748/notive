import NotesCore
import SwiftUI

/// メイン画面。サイドバー・ノート一覧・エディタの 3 ペイン構成（要件 7-3）。
struct MainView: View {
    private let appModel: AppViewModel
    @State private var sidebar: SidebarViewModel
    @State private var noteList: NoteListViewModel
    @State private var editor: EditorViewModel

    init(appModel: AppViewModel) {
        self.appModel = appModel
        _sidebar = State(initialValue: SidebarViewModel(folderService: appModel.folderService))
        _noteList = State(initialValue: NoteListViewModel(
            noteService: appModel.noteService,
            searchService: appModel.searchService
        ))
        _editor = State(initialValue: EditorViewModel(noteService: appModel.noteService))
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(sidebar: sidebar)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            NoteListView(noteList: noteList, workspaceID: workspaceID)
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 420)
        } detail: {
            EditorView(editor: editor)
        }
        .navigationTitle(appModel.currentWorkspace?.name ?? "Notive")
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
