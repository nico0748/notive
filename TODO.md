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
  フォルダ・一覧・検索・タグに対応
- 手書きブロック（F-INK-13）: iPad で PencilKit キャンバスにより描画。ストロークは
  `PKDrawing` ネイティブ形式（`Data`）で保存。タイプ済みテキストと混在配置可能
- 手書きの高度な編集: 投げ縄選択（F-INK-06、ツールピッカー標準）、図形補正（F-INK-08、
  直線・矩形・楕円）、前景／背景レイヤー（F-INK-11）、背景テンプレート（F-INK-12、
  罫線・方眼・ドット・五線譜・コーネル式）
- NotesCore のユニットテスト

## TODO（コード内コメントと対応）

- `Apps/NotesMac/Views/RootView.swift` — メール／パスワードおよび Sign in with Apple の実装（F-AUTH）。
- `Apps/NotesMac/Views/Blocks/BlockEditors.swift` — 画像添付（F-EDIT-03）の本実装。

## 未実装（後続イテレーションへの申し送り）

### 第2弾（手書き）の残り
- 手書きストロークの形式は `PKDrawing` ネイティブ `Data` を採用済み（要件 §11.2 の設計判断）。
  iPad での描画・再編集・テキスト混在は実装済み。**実機（Apple Pencil）での検証は未実施**
  （CI ではコンパイルのみ検証）。筆圧・傾き・低遅延（F-INK-02/03、5.1 の 30ms/60fps）は実機要確認。
- macOS 版のトラックパッド／マウス描画（F-INK-15）。現状 macOS は手書きブロックを
  プレースホルダ表示のみ（iPad で作成・編集する想定）。
- 図形補正（F-INK-08）は直線・矩形・楕円に対応。矢印の認識は未対応。
- レイヤー（F-INK-11）は前景／背景の 2 レイヤー固定。任意数レイヤー・並べ替えは未対応。
- 手書き文字の OCR・全文検索（F-INK-09／F-INK-10）。
- iPadOS アプリのリッチ編集（テキストは現状 Markdown ベース編集）。
- 画像添付の完成度向上（ドラッグ＆ドロップ、貼り付け）。

### 第3弾以降
- PDF 読み込み＋注釈（PDFKit）— `Block` に `case pdf` を追加予定。
- テキストボックス・図形挿入 — `Block` に `case textBox` / `case shape` を追加予定。
- エクスポート（Markdown / PDF / HTML）。
- バージョン履歴（F-EDIT-08、直近30日）。
- クラウド同期・共同編集・チームワークスペース・通知・メンション。
- OCR・手書きテキスト検索。

## 拡張ポイント（後続イテレーションへの注意点）

- **ブロック追加**: `Block` 列挙型に新ケースを追加し、`plainText` / `Block.id` /
  `MarkdownConverter` / macOS の `BlockListView` / iPad の `PadBlockRenderer` の分岐を
  更新する。永続化は `bodyData` の JSON に自動追従するためマイグレーション不要。
- **手書きデータ**: `InkBlock` は `PKDrawing.dataRepresentation()` を `Data` で保持する。
  ノートが大容量化する場合は SwiftData での別エンティティ化（遅延読み込み）を検討する。
  Markdown 往復では `EditorViewModel` が識別子経由でストローク実データを保持する。
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
