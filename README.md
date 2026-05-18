# Notive

MacBook（タイピング中心）と iPad（手書き中心）の2デバイスを前提とした、
タイプ済みテキストと手書きをシームレスに混在できるノートアプリ。

本リポジトリは v1.0 の **第1イテレーション（M1 基盤構築 + M2 macOS α版）** の成果物です。
要件の全体像は [`note_app_requirements_v1.0.md`](note_app_requirements_v1.0.md) を参照してください。

> 手書き・PDF 注釈・同期・共同編集などは後続イテレーションで実装します。
> 本イテレーションのスコープと残課題は [`TODO.md`](TODO.md) にまとめています。

---

## 動作環境

| 項目 | バージョン |
|------|-----------|
| Xcode | 15.4 以降 |
| macOS（実行・開発） | macOS 14 (Sonoma) 以降 |
| iPadOS | iPadOS 17 以降 |
| Swift | 5.10 以降 |
| 依存管理 | Swift Package Manager |

> **デプロイ対象についての注記**
> 要件定義書は macOS 13 / iPadOS 16 を指定していますが、第一候補の永続化技術
> **SwiftData は macOS 14 / iPadOS 17 以降が必須** です。開発オーナーの承認のもと、
> 本イテレーションではデプロイ対象を **macOS 14 / iPadOS 17** に引き上げて SwiftData を採用しました。

---

## セットアップ手順

Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で
`project.yml` から生成します（プロジェクトファイルはリポジトリにコミットしていません）。

```bash
# 1. XcodeGen をインストール（未導入の場合）
brew install xcodegen

# 2. リポジトリ直下でプロジェクトを生成
./Scripts/bootstrap.sh        # 内部で `xcodegen generate` を実行

# 3. 生成された Notive.xcodeproj を Xcode で開く
open Notive.xcodeproj
```

Xcode で **`Notive-macOS`** または **`Notive-iPadOS`** スキームを選択して実行してください
（初回ビルド時に Highlightr パッケージが自動解決されます）。

> 署名: ローカル実行のみであれば自動署名（Sign to Run Locally）で動作します。
> 必要に応じて Signing & Capabilities で開発チームを設定してください。

---

## 使い方（macOS α版）

1. 起動後、**「ローカルユーザーで開始」** を押すとローカルユーザーと個人ワークスペースが作成されます。
2. 左サイドバーでフォルダを作成・名前変更・削除（階層化対応）。
3. 中央ペインの **＋**（⌘N）でノートを作成。右ペインのエディタで編集。
4. エディタは **リッチ表示** と **Markdown 入力** を切り替え可能。
   ブロック（見出し／段落／リスト／引用／コード／チェックリスト／テーブル）を追加できます。
5. エディタのタイトル下の **タグバー**から、タグの作成・付与・解除ができます。
6. 入力停止から約 1.5 秒で **自動保存**。アプリを再起動してもデータは保持されます。
7. 中央ペイン上部の検索ボックスでタイトル・本文を検索できます。
8. ゴミ箱に入れたノートは 30 日経過後、起動時に自動削除されます。
9. ライト／ダークモードの双方に対応しています。

## 使い方（iPadOS）

iPadOS 版は macOS 版と同じ `NotesCore`（ドメイン・永続化・ViewModel）を共有し、
ノートの閲覧・編集・整理・検索・タグ付けに対応します。

1. 「ローカルユーザーで開始」後、3 カラム（サイドバー／ノート一覧／エディタ）で操作します。
2. エディタはツールバーの **編集／プレビュー**で切り替えます。編集は Markdown テキスト、
   プレビューはリッチ表示（見出し・リスト・コード・チェックリスト・テーブル等）です。
3. タイトル下のタグバーからタグを付与・作成できます。

> 手書き（Apple Pencil、PencilKit）は後続イテレーションで対応します。
> ストロークのデータ形式が要件定義書 §11.2 で未決の設計事項のため、本イテレーションでは扱いません。

---

## ディレクトリ構成

```
notive/
├── note_app_requirements_v1.0.md   要件定義書（参照用）
├── README.md / TODO.md
├── project.yml                     XcodeGen プロジェクト定義
├── .swiftlint.yml                  SwiftLint 設定
├── Scripts/bootstrap.sh            プロジェクト生成スクリプト
├── .github/workflows/ci.yml        CI（NotesCore テスト / SwiftLint / macOS・iPadOS ビルド）
├── Packages/
│   └── NotesCore/                  共有 Swift Package（プラットフォーム非依存ロジック）
│       └── Sources/NotesCore/
│           ├── Domain/             エンティティ・リポジトリ抽象（他層に非依存）
│           ├── Persistence/        SwiftData モデル・リポジトリ実装
│           ├── UseCases/           CRUD・検索・Markdown 変換
│           ├── ViewModels/         @Observable な ViewModel
│           └── Composition/        合成ルート（依存の結線）
└── Apps/
    ├── NotesMac/                   macOS アプリ（本イテレーションの実装対象）
    └── NotesPad/                   iPadOS アプリ（ノート閲覧・編集・タグ。手書きは後続）
```

### アーキテクチャ

```
UI (SwiftUI Views)  →  ViewModels (@Observable)  →  UseCases  →  Domain
                                                         ↑
                                          Persistence (SwiftData) ─┘
```

- **Domain は他層に非依存**。エンティティは純粋な値型で表現。
- 永続化は **リポジトリパターン** で抽象化し、SwiftData 実装を差し替え可能に。
- 依存はすべて **イニシャライザインジェクション**。結線は `Composition/AppComposition.swift` に集約。
- ノート本文は将来の手書き・PDF・図形に備え **ブロック配列（`Block`）** で表現。

---

## テスト

`NotesCore` パッケージのロジックは XCTest で検証しています。

```bash
cd Packages/NotesCore
swift test
```

ドメインモデル・Markdown 変換・ユースケース・SwiftData リポジトリ（インメモリ）を
カバーしています。UI テストは後続イテレーションで追加予定です。
