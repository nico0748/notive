import NotesCore
import SwiftUI

/// `Binding<Block>` から各ブロック種別の具体型へ射影するためのヘルパ。
///
/// SwiftUI の `TextField` などは具体型の `Binding` を要求するため、
/// 列挙型 `Block` の関連値を読み書きする橋渡しを提供する。
extension Binding where Value == Block {

    var headingBinding: Binding<HeadingBlock>? {
        guard case .heading = wrappedValue else { return nil }
        return Binding<HeadingBlock>(
            get: {
                if case .heading(let value) = wrappedValue { return value }
                return HeadingBlock()
            },
            set: { wrappedValue = .heading($0) }
        )
    }

    var paragraphBinding: Binding<ParagraphBlock>? {
        guard case .paragraph = wrappedValue else { return nil }
        return Binding<ParagraphBlock>(
            get: {
                if case .paragraph(let value) = wrappedValue { return value }
                return ParagraphBlock()
            },
            set: { wrappedValue = .paragraph($0) }
        )
    }

    var quoteBinding: Binding<QuoteBlock>? {
        guard case .quote = wrappedValue else { return nil }
        return Binding<QuoteBlock>(
            get: {
                if case .quote(let value) = wrappedValue { return value }
                return QuoteBlock()
            },
            set: { wrappedValue = .quote($0) }
        )
    }

    var codeBinding: Binding<CodeBlock>? {
        guard case .code = wrappedValue else { return nil }
        return Binding<CodeBlock>(
            get: {
                if case .code(let value) = wrappedValue { return value }
                return CodeBlock()
            },
            set: { wrappedValue = .code($0) }
        )
    }

    var checklistBinding: Binding<ChecklistBlock>? {
        guard case .checklist = wrappedValue else { return nil }
        return Binding<ChecklistBlock>(
            get: {
                if case .checklist(let value) = wrappedValue { return value }
                return ChecklistBlock()
            },
            set: { wrappedValue = .checklist($0) }
        )
    }

    var tableBinding: Binding<TableBlock>? {
        guard case .table = wrappedValue else { return nil }
        return Binding<TableBlock>(
            get: {
                if case .table(let value) = wrappedValue { return value }
                return TableBlock.makeDefault()
            },
            set: { wrappedValue = .table($0) }
        )
    }

    var imageBinding: Binding<ImageBlock>? {
        guard case .image = wrappedValue else { return nil }
        return Binding<ImageBlock>(
            get: {
                if case .image(let value) = wrappedValue { return value }
                return ImageBlock()
            },
            set: { wrappedValue = .image($0) }
        )
    }

    /// 箇条書き／番号付きリストはどちらも `ListBlock` を関連値に持つ。
    var listBinding: Binding<ListBlock>? {
        switch wrappedValue {
        case .bulletedList, .numberedList:
            return Binding<ListBlock>(
                get: {
                    switch wrappedValue {
                    case .bulletedList(let value), .numberedList(let value): return value
                    default: return ListBlock()
                    }
                },
                set: { newValue in
                    if case .numberedList = wrappedValue {
                        wrappedValue = .numberedList(newValue)
                    } else {
                        wrappedValue = .bulletedList(newValue)
                    }
                }
            )
        default:
            return nil
        }
    }
}
