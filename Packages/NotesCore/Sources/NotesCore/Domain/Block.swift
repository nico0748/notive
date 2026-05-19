import Foundation

/// ノート本文を構成する 1 要素を表すブロック。
///
/// 将来の手書き（`ink`）・PDF（`pdf`）・図形（`shape`）・テキストボックス（`textBox`）
/// といったブロック種別を追加できるよう列挙型で表現している。本イテレーションでは
/// テキスト系・コード・チェックリスト・テーブル・画像のみを実装する。
public enum Block: Identifiable, Codable, Hashable, Sendable {
    case heading(HeadingBlock)
    case paragraph(ParagraphBlock)
    case bulletedList(ListBlock)
    case numberedList(ListBlock)
    case quote(QuoteBlock)
    case code(CodeBlock)
    case checklist(ChecklistBlock)
    case table(TableBlock)
    case image(ImageBlock)
    case ink(InkBlock)
    // 将来追加予定:
    // case pdf(PdfBlock)
    // case shape(ShapeBlock)
    // case textBox(TextBoxBlock)

    public var id: UUID {
        switch self {
        case .heading(let block): return block.id
        case .paragraph(let block): return block.id
        case .bulletedList(let block): return block.id
        case .numberedList(let block): return block.id
        case .quote(let block): return block.id
        case .code(let block): return block.id
        case .checklist(let block): return block.id
        case .table(let block): return block.id
        case .image(let block): return block.id
        case .ink(let block): return block.id
        }
    }

    /// 実装済みのブロック種別数。
    public static let implementedKindCount = 10

    /// 全文検索（F-SEARCH-01）で参照するプレーンテキスト表現。
    public var plainText: String {
        switch self {
        case .heading(let block): return block.text
        case .paragraph(let block): return block.text
        case .bulletedList(let block): return block.items.joined(separator: "\n")
        case .numberedList(let block): return block.items.joined(separator: "\n")
        case .quote(let block): return block.text
        case .code(let block): return block.code
        case .checklist(let block): return block.items.map(\.text).joined(separator: "\n")
        case .table(let block):
            return (block.headers + block.rows.flatMap { $0 }).joined(separator: " ")
        case .image(let block): return block.caption
        // 手書きの全文検索（OCR、F-INK-10）は後続イテレーションで対応する。
        case .ink: return ""
        }
    }
}

/// 見出しブロック（F-EDIT-01）。
public struct HeadingBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 見出しレベル。`NotesConstants.Heading` の範囲に収める。
    public var level: Int
    public var text: String

    public init(id: UUID = UUID(), level: Int = NotesConstants.Heading.minLevel, text: String = "") {
        self.id = id
        self.level = min(max(level, NotesConstants.Heading.minLevel), NotesConstants.Heading.maxLevel)
        self.text = text
    }
}

/// 段落ブロック（F-EDIT-01）。`text` には `**bold**` などのインライン Markdown を含められる。
public struct ParagraphBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

/// 箇条書き／番号付きリストブロック（F-EDIT-01）。
public struct ListBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var items: [String]

    public init(id: UUID = UUID(), items: [String] = [""]) {
        self.id = id
        self.items = items
    }
}

/// 引用ブロック（F-EDIT-01）。
public struct QuoteBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }
}

/// コードブロック（F-EDIT-04）。`language` が `nil` の場合は自動判定に委ねる。
public struct CodeBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var language: String?
    public var code: String

    public init(id: UUID = UUID(), language: String? = nil, code: String = "") {
        self.id = id
        self.language = language
        self.code = code
    }
}

/// チェックリストの 1 項目（F-EDIT-05）。
public struct ChecklistItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var text: String
    public var isDone: Bool

    public init(id: UUID = UUID(), text: String = "", isDone: Bool = false) {
        self.id = id
        self.text = text
        self.isDone = isDone
    }
}

/// チェックリストブロック（F-EDIT-05）。
public struct ChecklistBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var items: [ChecklistItem]

    public init(id: UUID = UUID(), items: [ChecklistItem] = [ChecklistItem()]) {
        self.id = id
        self.items = items
    }
}

/// テーブルブロック（F-EDIT-06）。最小実装として行列の追加とセル編集をサポートする。
public struct TableBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// ヘッダ行のセル。要素数が列数を表す。
    public var headers: [String]
    /// データ行。各行は `headers.count` 個のセルを持つ。
    public var rows: [[String]]

    public init(id: UUID = UUID(), headers: [String], rows: [[String]]) {
        self.id = id
        self.headers = headers
        self.rows = rows
    }

    /// 既定サイズの空テーブルを生成する。
    public static func makeDefault() -> TableBlock {
        let columns = NotesConstants.Table.defaultColumnCount
        let dataRows = NotesConstants.Table.defaultRowCount
        return TableBlock(
            headers: Array(repeating: "", count: columns),
            rows: Array(repeating: Array(repeating: "", count: columns), count: dataRows)
        )
    }

    public var columnCount: Int { headers.count }
}

/// 画像ブロック（F-EDIT-03 の基本添付）。本イテレーションでは型のみ用意する。
public struct ImageBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 紐づく添付ファイルの識別子。未添付の場合は `nil`。
    public var attachmentID: UUID?
    public var caption: String

    public init(id: UUID = UUID(), attachmentID: UUID? = nil, caption: String = "") {
        self.id = id
        self.attachmentID = attachmentID
        self.caption = caption
    }
}

/// 手書きブロックの背景テンプレート（F-INK-12、罫線・方眼・ドット・五線譜・コーネル式）。
public enum InkTemplate: String, Codable, CaseIterable, Sendable {
    case blank
    case ruled
    case grid
    case dots
    case staff
    case cornell

    /// UI 表示用の名称。
    public var displayName: String {
        switch self {
        case .blank: return "なし"
        case .ruled: return "罫線"
        case .grid: return "方眼"
        case .dots: return "ドット"
        case .staff: return "五線譜"
        case .cornell: return "コーネル式"
        }
    }
}

/// 手書きブロック（F-INK-13、タイプ済みテキストと手書きの混在配置）。
///
/// ストロークは PencilKit の `PKDrawing.dataRepresentation()` をそのまま保持する
/// （要件定義書 §11.2 の設計判断: v1.0 は Apple エコシステム専用のため
/// ネイティブ形式を採用し、ロスレス・低実装コストを優先する）。
/// `NotesCore` は PencilKit に依存せず、ストロークを不透明な `Data` として扱う。
///
/// 手書きは前景・背景の 2 レイヤーに分離して保持する（F-INK-11）。表示時は
/// テンプレート → 背景レイヤー → 前景レイヤーの順に合成する。
public struct InkBlock: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// 前景レイヤーの `PKDrawing.dataRepresentation()` のバイト列。
    public var drawingData: Data
    /// 背景レイヤーの `PKDrawing.dataRepresentation()` のバイト列（F-INK-11）。
    public var backgroundData: Data
    /// 背景テンプレート（F-INK-12）。
    public var template: InkTemplate
    /// 手書きキャンバスの表示高さ（ポイント）。
    public var height: Double

    public init(id: UUID = UUID(),
                drawingData: Data = Data(),
                backgroundData: Data = Data(),
                template: InkTemplate = .blank,
                height: Double = InkBlock.defaultHeight) {
        self.id = id
        self.drawingData = drawingData
        self.backgroundData = backgroundData
        self.template = template
        self.height = height
    }

    /// 手書きキャンバスの既定の高さ（ポイント）。
    public static let defaultHeight: Double = 280

    /// いずれのレイヤーにもストロークが無いか。
    public var isEmpty: Bool { drawingData.isEmpty && backgroundData.isEmpty }

    private enum CodingKeys: String, CodingKey {
        case id, drawingData, backgroundData, template, height
    }

    /// 旧フォーマット（`drawingData` / `height` のみ）のノートもデコードできるよう、
    /// 後から追加した `backgroundData` / `template` は欠落時に既定値で補う。
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        drawingData = try container.decode(Data.self, forKey: .drawingData)
        backgroundData = try container.decodeIfPresent(Data.self, forKey: .backgroundData) ?? Data()
        template = try container.decodeIfPresent(InkTemplate.self, forKey: .template) ?? .blank
        height = try container.decode(Double.self, forKey: .height)
    }
}
