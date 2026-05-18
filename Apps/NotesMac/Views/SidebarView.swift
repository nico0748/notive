import NotesCore
import SwiftUI

/// サイドバー（フォルダツリー）。ライブラリ項目とフォルダ階層を表示する（F-ORG-02）。
struct SidebarView: View {
    @Bindable var sidebar: SidebarViewModel

    @State private var renamingFolder: Folder?
    @State private var renameText: String = ""

    var body: some View {
        List(selection: selectionBinding) {
            Section("ライブラリ") {
                Label("すべてのノート", systemImage: "tray.full")
                    .tag(SidebarSelection.allNotes)
                Label("お気に入り", systemImage: "star")
                    .tag(SidebarSelection.favorites)
                Label("ゴミ箱", systemImage: "trash")
                    .tag(SidebarSelection.trash)
            }

            Section("フォルダ") {
                FolderTree(
                    sidebar: sidebar,
                    parentID: nil,
                    depth: 0,
                    onRename: beginRename
                )
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await sidebar.createFolder(parentID: nil) }
                } label: {
                    Label("フォルダを追加", systemImage: "folder.badge.plus")
                }
            }
        }
        .alert("フォルダ名を変更", isPresented: renameBinding) {
            TextField("フォルダ名", text: $renameText)
            Button("変更") {
                if let folder = renamingFolder {
                    Task { await sidebar.rename(folder, to: renameText) }
                }
                renamingFolder = nil
            }
            Button("キャンセル", role: .cancel) { renamingFolder = nil }
        }
    }

    /// `List` の単一選択は省略可能バインディングを要求するため、非省略の選択状態へ橋渡しする。
    private var selectionBinding: Binding<SidebarSelection?> {
        Binding(
            get: { sidebar.selection },
            set: { sidebar.selection = $0 ?? .allNotes }
        )
    }

    private var renameBinding: Binding<Bool> {
        Binding(
            get: { renamingFolder != nil },
            set: { if !$0 { renamingFolder = nil } }
        )
    }

    private func beginRename(_ folder: Folder) {
        renameText = folder.name
        renamingFolder = folder
    }
}

/// フォルダ階層を再帰的に描画するビュー。
///
/// 不透明戻り値型は自己再帰できないため、具体的な `View` 型として定義する。
private struct FolderTree: View {
    let sidebar: SidebarViewModel
    let parentID: UUID?
    let depth: Int
    let onRename: (Folder) -> Void

    var body: some View {
        ForEach(sidebar.childFolders(of: parentID)) { folder in
            Label(folder.name, systemImage: "folder")
                .padding(.leading, CGFloat(depth) * 12)
                .tag(SidebarSelection.folder(folder.id))
                .contextMenu {
                    Button("名前を変更") { onRename(folder) }
                    Button("サブフォルダを追加") {
                        Task { await sidebar.createFolder(parentID: folder.id) }
                    }
                    Divider()
                    Button("削除", role: .destructive) {
                        Task { await sidebar.delete(folder) }
                    }
                }

            FolderTree(
                sidebar: sidebar,
                parentID: folder.id,
                depth: depth + 1,
                onRename: onRename
            )
        }
    }
}
