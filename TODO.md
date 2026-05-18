# Notive — 残課題と申し送り

第1イテレーション（M1 基盤 + M2 macOS α版）時点の残課題一覧。

## 設計判断（独断ではなく承認済み／報告事項）

- **デプロイ対象を macOS 14 / iPadOS 17 へ引き上げ**
  SwiftData は macOS 14 / iPadOS 17 以降が必須のため、要件の macOS 13 / iPadOS 16 では
  利用できない。開発オーナーの承認のもと SwiftData を採用し、デプロイ対象を引き上げた。
  macOS 13 / iPadOS 16 対応が必須要件に戻る場合は Core Data へのフォールバックが必要。
- **ViewModel は `@Observable`（Observation フレームワーク）を採用**。Combine は不使用。
- **Xcode プロジェクトは XcodeGen 管理**。`project.yml` から生成し、`.xcodeproj` は
  コミットしない（README のセットアップ手順を参照）。
- **シンタックスハイライトに Highlightr を採用**（highlight.js ベース、多言語対応）。
- **SwiftData エンティティはリレーションシップを使わず `UUID` 参照で関連を表現**。
  カスケード削除をサービス層で明示制御でき、将来のストア差し替え時の影響を限定するため。
- ノート本文ブロックは `NoteEntity.bodyData`（JSON エンコード済み `Data`）として保存。
  SwiftData の Codable 列挙型サポートのバージョン差異を避けるための判断。

## 実装済み（このイテレーションのスコープ）

- プロジェクト基盤（XcodeGen / SwiftLint / GitHub Actions CI）
- ドメインモデル（User / Workspace / Folder / Note / Block / Tag）
- SwiftData 永続化とリポジトリ実装
- ユースケース（ノート CRUD・フォルダ CRUD・検索・Markdown 変換）
- macOS アプリ: ログインスタブ / 3ペイン / フォルダ階層 / ノート CRUD / ゴミ箱
- エディタ: 見出し・太字・リスト・引用（F-EDIT-01）、Markdown 切替（F-EDIT-02）、
  コードブロック（F-EDIT-04）、チェックリスト（F-EDIT-05）、テーブル（F-EDIT-06）、
  自動保存（F-EDIT-07）
- タイトル・本文検索（F-SEARCH-01）
- タグの作成・付与・解除（F-ORG-03、エディタ上の UI）
- ゴミ箱の自動パージ（F-ORG-05、起動時に30日経過分を削除）
- ダーク／ライトモード対応
- iPadOS アプリ: NotesCore を共有し、ノート閲覧・編集（Markdown／プレビュー）・
  フォルダ・一覧・検索・タグに対応（手書きは未対応）
- NotesCore のユニットテスト

## TODO（コード内コメントと対応）

- `Apps/NotesMac/Views/RootView.swift` — メール／パスワードおよび Sign in with Apple の実装（F-AUTH）。
- `Apps/NotesMac/Views/Blocks/BlockEditors.swift` — 画像添付（F-EDIT-03）の本実装。

## 未実装（後続イテレーションへの申し送り）

### 第2弾（手書き）
- 手書き・描画（PencilKit、Apple Pencil、筆圧／傾き）— `Block` 列挙型に `case ink` を追加予定。
  **着手前に要決定**: ストロークのデータ形式（独自バイナリ／JSON ベクター／InkML 互換）。
  要件定義書 §11.2 の未決事項であり、ハードウェア検証も必要なため独立した実装依頼が望ましい。
- iPadOS アプリのリッチ編集（現在は Markdown ベース編集）。ブロック単位のインライン編集や
  コードのシンタックスハイライトは macOS 版と同等まで引き上げる余地がある。
- 画像添付の完成度向上（ドラッグ＆ドロップ、貼り付け）。

### 第3弾以降
- PDF 読み込み＋注釈（PDFKit）— `Block` に `case pdf` を追加予定。
- テキストボックス・図形挿入 — `Block` に `case textBox` / `case shape` を追加予定。
- エクスポート（Markdown / PDF / HTML）。
- バージョン履歴（F-EDIT-08、直近30日）。
- クラウド同期・共同編集・チームワークスペース・通知・メンション。
- OCR・手書きテキスト検索。

## 拡張ポイント（手書きイテレーションへの注意点）

- **ブロック追加**: `Block` 列挙型に新ケースを追加し、`plainText` / `MarkdownConverter` /
  `BlockBindings` / `BlockListView` の分岐を更新する。永続化は `bodyData` の JSON に
  自動追従するためマイグレーション不要。
- **手書きデータ**: ストロークはベクター（座標列＋筆圧）で保持する想定。`InkBlock` を
  新設し、SwiftData では別エンティティ化も検討（大容量になりうるため）。
- **リポジトリ抽象**: `NoteRepository` 等のプロトコルは同期バックエンド実装に
  差し替え可能。共同編集導入時は CRDT 対応リポジトリを追加する。
- **検索**: 現状は線形の部分一致。ノート数増加時は SwiftData の `#Predicate` による
  ストア側フィルタや全文検索インデックスへの移行が必要。

## 既知の制約

- ノート一覧はエディタ保存後に再読み込みするが、大量ノート時の最適化は未対応。
- タグはエディタからの作成・付与・解除に対応済み。ノート一覧でのタグチップ表示や
  タグによる絞り込み検索（F-SEARCH-02）は後続イテレーションで追加する。
- ゴミ箱の自動パージは起動時に実行する。アプリ常駐中の定期実行は未対応
  （長時間起動しっぱなしの場合は次回起動時にまとめて削除される）。
- **SwiftData リポジトリのユニットテスト（`SwiftDataRepositoryTests`）**は、
  ホストアプリを持たないヘッドレスな `swift test`（CI）環境で SwiftData の
  インメモリ `ModelContainer` が SIGTRAP クラッシュするため、CI ではスキップする
  （環境変数 `CI` で判定）。Xcode 上では正常に実行できる。ドメイン／ユースケースの
  ロジックはインメモリのフェイクリポジトリで検証済み。CI でも検証したい場合は、
  ホストアプリ付きの `xcodebuild test` への移行を検討する。
