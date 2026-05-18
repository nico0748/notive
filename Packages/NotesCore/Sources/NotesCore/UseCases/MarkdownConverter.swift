import Foundation

/// ブロック配列と Markdown テキストを相互変換する（F-EDIT-02）。
///
/// エディタの「Markdown 入力モード」と「リッチ表示モード」を切り替える際に用いる、
/// 最小実装の行ベースパーサ。完全な Markdown 仕様は満たさないが、本アプリが
/// 生成するブロック種別の往復変換を担保する。
public struct MarkdownConverter {

    public init() {}

    // MARK: - ブロック → Markdown

    /// ブロック配列を Markdown 文字列へ変換する。
    public func markdown(from blocks: [Block]) -> String {
        blocks.map(markdown(from:)).joined(separator: "\n\n")
    }

    private func markdown(from block: Block) -> String {
        switch block {
        case .heading(let heading):
            return String(repeating: "#", count: heading.level) + " " + heading.text
        case .paragraph(let paragraph):
            return paragraph.text
        case .bulletedList(let list):
            return list.items.map { "- \($0)" }.joined(separator: "\n")
        case .numberedList(let list):
            return list.items.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: "\n")
        case .quote(let quote):
            return quote.text.split(separator: "\n", omittingEmptySubsequences: false)
                .map { "> \($0)" }.joined(separator: "\n")
        case .code(let code):
            let fenceInfo = code.language ?? ""
            return "```\(fenceInfo)\n\(code.code)\n```"
        case .checklist(let checklist):
            return checklist.items.map { "- [\($0.isDone ? "x" : " ")] \($0.text)" }.joined(separator: "\n")
        case .table(let table):
            return markdown(from: table)
        case .image(let image):
            let reference = image.attachmentID.map { "attachment:\($0.uuidString)" } ?? ""
            return "![\(image.caption)](\(reference))"
        }
    }

    private func markdown(from table: TableBlock) -> String {
        let headerLine = "| " + table.headers.joined(separator: " | ") + " |"
        let separatorLine = "| " + Array(repeating: "---", count: table.columnCount).joined(separator: " | ") + " |"
        let rowLines = table.rows.map { "| " + $0.joined(separator: " | ") + " |" }
        return ([headerLine, separatorLine] + rowLines).joined(separator: "\n")
    }

    // MARK: - Markdown → ブロック

    /// Markdown 文字列をブロック配列へ変換する。
    public func blocks(from markdown: String) -> [Block] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [Block] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
            } else if trimmed.hasPrefix("```") {
                let (block, next) = parseCodeBlock(lines, from: index)
                blocks.append(block)
                index = next
            } else if let heading = parseHeading(trimmed) {
                blocks.append(.heading(heading))
                index += 1
            } else if trimmed.hasPrefix("![") {
                blocks.append(.image(parseImage(trimmed)))
                index += 1
            } else if isChecklistLine(trimmed) {
                let (block, next) = parseChecklist(lines, from: index)
                blocks.append(block)
                index = next
            } else if trimmed.hasPrefix("> ") || trimmed == ">" {
                let (block, next) = parseQuote(lines, from: index)
                blocks.append(block)
                index = next
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                let (block, next) = parseBulletedList(lines, from: index)
                blocks.append(block)
                index = next
            } else if numberedListContent(of: trimmed) != nil {
                let (block, next) = parseNumberedList(lines, from: index)
                blocks.append(block)
                index = next
            } else if trimmed.hasPrefix("|") {
                let (block, next) = parseTable(lines, from: index)
                blocks.append(block)
                index = next
            } else {
                let (block, next) = parseParagraph(lines, from: index)
                blocks.append(block)
                index = next
            }
        }

        return blocks.isEmpty ? [.paragraph(ParagraphBlock())] : blocks
    }

    // MARK: - 各ブロックのパース

    private func parseHeading(_ trimmed: String) -> HeadingBlock? {
        var level = 0
        for character in trimmed {
            if character == "#" { level += 1 } else { break }
        }
        guard level >= 1, level <= 6 else { return nil }
        let remainder = trimmed.dropFirst(level)
        guard remainder.first == " " else { return nil }
        return HeadingBlock(level: level, text: String(remainder.dropFirst()))
    }

    private func parseCodeBlock(_ lines: [String], from start: Int) -> (Block, Int) {
        let opening = lines[start].trimmingCharacters(in: .whitespaces)
        let language = String(opening.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var index = start + 1
        var codeLines: [String] = []
        while index < lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                index += 1
                break
            }
            codeLines.append(lines[index])
            index += 1
        }
        let block = CodeBlock(language: language.isEmpty ? nil : language, code: codeLines.joined(separator: "\n"))
        return (.code(block), index)
    }

    private func parseImage(_ trimmed: String) -> ImageBlock {
        guard let captionEnd = trimmed.firstIndex(of: "]") else {
            return ImageBlock(caption: "")
        }
        let captionStart = trimmed.index(trimmed.startIndex, offsetBy: 2)
        let caption = String(trimmed[captionStart..<captionEnd])
        var attachmentID: UUID?
        if let openParen = trimmed.firstIndex(of: "("),
           let closeParen = trimmed.lastIndex(of: ")"),
           openParen < closeParen {
            let reference = String(trimmed[trimmed.index(after: openParen)..<closeParen])
            if reference.hasPrefix("attachment:") {
                attachmentID = UUID(uuidString: String(reference.dropFirst("attachment:".count)))
            }
        }
        return ImageBlock(attachmentID: attachmentID, caption: caption)
    }

    private func isChecklistLine(_ trimmed: String) -> Bool {
        trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
    }

    private func parseChecklist(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var items: [ChecklistItem] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard isChecklistLine(trimmed) else { break }
            let isDone = trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ")
            let text = String(trimmed.dropFirst("- [ ] ".count))
            items.append(ChecklistItem(text: text, isDone: isDone))
            index += 1
        }
        return (.checklist(ChecklistBlock(items: items)), index)
    }

    private func parseQuote(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var quoteLines: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("> ") {
                quoteLines.append(String(trimmed.dropFirst(2)))
            } else if trimmed == ">" {
                quoteLines.append("")
            } else {
                break
            }
            index += 1
        }
        return (.quote(QuoteBlock(text: quoteLines.joined(separator: "\n"))), index)
    }

    private func parseBulletedList(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var items: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                items.append(String(trimmed.dropFirst(2)))
                index += 1
            } else {
                break
            }
        }
        return (.bulletedList(ListBlock(items: items)), index)
    }

    private func numberedListContent(of trimmed: String) -> String? {
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return nil }
        let prefix = trimmed[trimmed.startIndex..<dotIndex]
        guard !prefix.isEmpty, prefix.allSatisfy(\.isNumber) else { return nil }
        let afterDot = trimmed.index(after: dotIndex)
        guard afterDot < trimmed.endIndex, trimmed[afterDot] == " " else { return nil }
        return String(trimmed[trimmed.index(after: afterDot)...])
    }

    private func parseNumberedList(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var items: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard let content = numberedListContent(of: trimmed) else { break }
            items.append(content)
            index += 1
        }
        return (.numberedList(ListBlock(items: items)), index)
    }

    private func parseTable(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var tableLines: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("|") else { break }
            tableLines.append(trimmed)
            index += 1
        }

        func cells(of line: String) -> [String] {
            var trimmed = line
            if trimmed.hasPrefix("|") { trimmed.removeFirst() }
            if trimmed.hasSuffix("|") { trimmed.removeLast() }
            return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        }

        func isSeparator(_ line: String) -> Bool {
            cells(of: line).allSatisfy { cell in
                !cell.isEmpty && cell.allSatisfy { $0 == "-" || $0 == ":" }
            }
        }

        let headers = tableLines.first.map(cells) ?? []
        var rows: [[String]] = []
        for line in tableLines.dropFirst() where !isSeparator(line) {
            var row = cells(of: line)
            while row.count < headers.count { row.append("") }
            rows.append(Array(row.prefix(headers.count)))
        }
        return (.table(TableBlock(headers: headers, rows: rows)), index)
    }

    private func parseParagraph(_ lines: [String], from start: Int) -> (Block, Int) {
        var index = start
        var paragraphLines: [String] = []
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty
                || trimmed.hasPrefix("#")
                || trimmed.hasPrefix("```")
                || trimmed.hasPrefix("> ")
                || trimmed.hasPrefix("- ")
                || trimmed.hasPrefix("* ")
                || trimmed.hasPrefix("|")
                || trimmed.hasPrefix("![")
                || numberedListContent(of: trimmed) != nil {
                break
            }
            paragraphLines.append(lines[index])
            index += 1
        }
        return (.paragraph(ParagraphBlock(text: paragraphLines.joined(separator: "\n"))), index)
    }
}
