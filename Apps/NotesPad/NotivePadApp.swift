import NotesCore
import SwiftData
import SwiftUI

/// Notive（iPadOS）のエントリポイント。
///
/// 永続ストア（SwiftData `ModelContainer`）と合成ルートを初期化し、
/// `AppViewModel` を環境へ注入する。ロジック層は macOS 版と共通の `NotesCore` を用いる。
@main
struct NotivePadApp: App {
    @State private var appModel: AppViewModel
    private let container: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainerFactory.makeContainer()
        } catch {
            // 永続ストアを生成できない場合はアプリを継続できないため停止する。
            fatalError("永続ストアの初期化に失敗しました: \(error)")
        }
        self.container = container
        _appModel = State(initialValue: AppComposition.makeAppViewModel(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            PadRootView()
                .environment(appModel)
        }
        .modelContainer(container)
    }
}
