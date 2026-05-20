import NotesCore
import SwiftUI

/// バージョン履歴の閲覧・復元シート（F-EDIT-08、iPadOS）。
struct PadVersionHistoryView: View {
    @Bindable var editor: EditorViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var versions: [NoteVersion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("バージョン履歴")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
        .task { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let message = errorMessage {
            VStack(spacing: 8) {
                Text("履歴の取得に失敗しました")
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if versions.isEmpty {
            ContentUnavailableView(
                "履歴はありません",
                systemImage: "clock.arrow.circlepath",
                description: Text("編集を行うと自動でバージョンが保存されます。")
            )
        } else {
            List(versions) { version in
                PadVersionRow(version: version) {
                    Task {
                        await editor.restore(version: version)
                        dismiss()
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            versions = try await editor.versions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// 履歴 1 件分の行表示（iPadOS）。
private struct PadVersionRow: View {
    let version: NoteVersion
    let onRestore: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(version.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.body)
                Text(version.title.isEmpty ? "(無題)" : version.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("復元", action: onRestore)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding(.vertical, 4)
    }
}
