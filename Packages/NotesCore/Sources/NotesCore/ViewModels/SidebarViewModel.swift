import Foundation
import Observation

/// サイドバーで選択中の項目（F-ORG-02 / F-ORG-04 / F-ORG-05）。
public enum SidebarSelection: Hashable, Sendable {
    /// ゴミ箱を除く全ノート。
    case allNotes
    /// お気に入りに登録されたノート。
    case favorites
    /// ゴミ箱。
    case trash
    /// 特定フォルダ。
    case folder(UUID)
}

/// サイドバー（フォルダツリー）の状態とフォルダ操作を担う ViewModel。
@MainActor
@Observable
public final class SidebarViewModel {
    public private(set) var folders: [Folder] = []
    public var selection: SidebarSelection = .allNotes
    public var errorMessage: String?

    private let folderService: FolderService
    private var workspaceID: UUID?

    public init(folderService: FolderService) {
        self.folderService = folderService
    }

    /// 指定ワークスペースのフォルダ一覧を読み込む。
    public func load(workspaceID: UUID) async {
        self.workspaceID = workspaceID
        await reload()
    }

    /// フォルダ一覧を再取得する。
    public func reload() async {
        guard let workspaceID else { return }
        do {
            folders = try await folderService.folders(in: workspaceID)
        } catch {
            errorMessage = "フォルダの読み込みに失敗しました: \(error.localizedDescription)"
        }
    }

    /// 指定した親フォルダの直下フォルダを `sortIndex` 順で返す。
    public func childFolders(of parentID: UUID?) -> [Folder] {
        folders
            .filter { $0.parentID == parentID }
            .sorted { $0.sortIndex < $1.sortIndex }
    }

    /// フォルダを新規作成する。
    public func createFolder(parentID: UUID? = nil) async {
        guard let workspaceID else { return }
        do {
            let folder = try await folderService.createFolder(in: workspaceID, parentID: parentID)
            await reload()
            selection = .folder(folder.id)
        } catch {
            errorMessage = "フォルダの作成に失敗しました: \(error.localizedDescription)"
        }
    }

    /// フォルダ名を変更する。
    public func rename(_ folder: Folder, to name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await folderService.rename(folder, to: trimmed)
            await reload()
        } catch {
            errorMessage = "フォルダ名の変更に失敗しました: \(error.localizedDescription)"
        }
    }

    /// フォルダを子孫ごと削除する。選択中フォルダが消えた場合は全ノートへ戻す。
    public func delete(_ folder: Folder) async {
        do {
            try await folderService.delete(folder)
            if selection == .folder(folder.id) {
                selection = .allNotes
            }
            await reload()
        } catch {
            errorMessage = "フォルダの削除に失敗しました: \(error.localizedDescription)"
        }
    }
}
