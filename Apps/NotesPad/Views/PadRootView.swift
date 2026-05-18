import NotesCore
import SwiftUI

/// iPadOS 版のプレースホルダ画面（空シェル）。
///
/// 共有パッケージ `NotesCore` への依存のみ確認し、UI 実装は後続イテレーションで行う。
struct PadRootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "applepencil.and.scribble")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Notive for iPad")
                .font(.largeTitle.bold())
            Text("手書き・PDF 注釈に対応した iPad 版は後続イテレーションで提供します。")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            // 共有ドメインがリンクされていることの確認。
            Text("共有モジュール: NotesCore（ブロック種別 \(Block.implementedKindCount) 種を実装済み）")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(48)
    }
}
