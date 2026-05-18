import NotesCore
import SwiftUI

/// Notive（iPadOS）のエントリポイント。
///
/// 本イテレーション（M1 + M2α）では iPadOS アプリは空シェルとし、
/// ビルド可能な状態のみを保証する。手書き・PDF 注釈を含む本実装は
/// 第2弾以降で対応する。
@main
struct NotivePadApp: App {
    var body: some Scene {
        WindowGroup {
            PadRootView()
        }
    }
}
