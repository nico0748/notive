import XCTest
@testable import NotesCore

final class MarkdownConverterTests: XCTestCase {

    private let converter = MarkdownConverter()

    func testParsesHeading() {
        let blocks = converter.blocks(from: "## 見出し")
        guard case .heading(let heading) = blocks.first else {
            return XCTFail("見出しブロックが生成されていない")
        }
        XCTAssertEqual(heading.level, 2)
        XCTAssertEqual(heading.text, "見出し")
    }

    func testParsesCodeBlockWithLanguage() {
        let markdown = "```swift\nlet x = 1\nlet y = 2\n```"
        let blocks = converter.blocks(from: markdown)
        guard case .code(let code) = blocks.first else {
            return XCTFail("コードブロックが生成されていない")
        }
        XCTAssertEqual(code.language, "swift")
        XCTAssertEqual(code.code, "let x = 1\nlet y = 2")
    }

    func testParsesChecklist() {
        let markdown = "- [ ] 未完了\n- [x] 完了"
        let blocks = converter.blocks(from: markdown)
        guard case .checklist(let checklist) = blocks.first else {
            return XCTFail("チェックリストが生成されていない")
        }
        XCTAssertEqual(checklist.items.count, 2)
        XCTAssertFalse(checklist.items[0].isDone)
        XCTAssertTrue(checklist.items[1].isDone)
    }

    func testParsesBulletedAndNumberedLists() {
        guard case .bulletedList(let bullets) = converter.blocks(from: "- a\n- b").first else {
            return XCTFail("箇条書きリストが生成されていない")
        }
        XCTAssertEqual(bullets.items, ["a", "b"])

        guard case .numberedList(let numbers) = converter.blocks(from: "1. one\n2. two").first else {
            return XCTFail("番号付きリストが生成されていない")
        }
        XCTAssertEqual(numbers.items, ["one", "two"])
    }

    func testParsesTable() {
        let markdown = "| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |"
        let blocks = converter.blocks(from: markdown)
        guard case .table(let table) = blocks.first else {
            return XCTFail("テーブルが生成されていない")
        }
        XCTAssertEqual(table.headers, ["A", "B"])
        XCTAssertEqual(table.rows, [["1", "2"], ["3", "4"]])
    }

    func testParsesQuote() {
        guard case .quote(let quote) = converter.blocks(from: "> 引用文").first else {
            return XCTFail("引用ブロックが生成されていない")
        }
        XCTAssertEqual(quote.text, "引用文")
    }

    func testEmptyMarkdownProducesSingleParagraph() {
        let blocks = converter.blocks(from: "")
        XCTAssertEqual(blocks.count, 1)
        guard case .paragraph = blocks.first else {
            return XCTFail("空段落が生成されていない")
        }
    }

    func testRoundTripPreservesBlockKinds() {
        let original: [Block] = [
            .heading(HeadingBlock(level: 1, text: "タイトル")),
            .paragraph(ParagraphBlock(text: "本文の段落")),
            .bulletedList(ListBlock(items: ["項目1", "項目2"])),
            .checklist(ChecklistBlock(items: [
                ChecklistItem(text: "タスク", isDone: true)
            ])),
            .code(CodeBlock(language: "python", code: "print(1)")),
            .table(TableBlock(headers: ["列1", "列2"], rows: [["a", "b"]]))
        ]
        let markdown = converter.markdown(from: original)
        let restored = converter.blocks(from: markdown)

        XCTAssertEqual(restored.count, original.count)
        for (lhs, rhs) in zip(original, restored) {
            XCTAssertEqual(blockKind(lhs), blockKind(rhs))
        }
    }

    private func blockKind(_ block: Block) -> String {
        switch block {
        case .heading: return "heading"
        case .paragraph: return "paragraph"
        case .bulletedList: return "bulletedList"
        case .numberedList: return "numberedList"
        case .quote: return "quote"
        case .code: return "code"
        case .checklist: return "checklist"
        case .table: return "table"
        case .image: return "image"
        }
    }
}
