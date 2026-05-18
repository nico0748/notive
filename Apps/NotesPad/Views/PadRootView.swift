import NotesCore
import SwiftUI

/// 起動フェーズに応じてログイン画面・メイン画面を切り替える iPadOS のルートビュー。
struct PadRootView: View {
    @Environment(AppViewModel.self) private var appModel

    var body: some View {
        Group {
            switch appModel.phase {
            case .loading:
                ProgressView("読み込み中…")
            case .login:
                PadLoginView()
            case .ready:
                PadMainView(appModel: appModel)
            }
        }
        .task {
            if appModel.phase == .loading {
                await appModel.bootstrap()
            }
        }
    }
}

/// サインアップ／ログインのスタブ画面（iPadOS）。
///
/// 認証バックエンド（F-AUTH-01〜05）は後続イテレーションで実装するため、
/// 本イテレーションでは「ローカルユーザーで開始」のみを提供する。
struct PadLoginView: View {
    @Environment(AppViewModel.self) private var appModel
    @State private var isStarting = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "note.text")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Notive for iPad")
                .font(.largeTitle.bold())
            Text("MacBook と iPad のためのハイブリッドノート")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button {
                isStarting = true
                Task {
                    await appModel.startAsLocalUser()
                    isStarting = false
                }
            } label: {
                Text("ローカルユーザーで開始")
                    .frame(maxWidth: 280)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(isStarting)

            Text("手書き（Apple Pencil）は後続イテレーションで対応予定です。")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let message = appModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(48)
    }
}
