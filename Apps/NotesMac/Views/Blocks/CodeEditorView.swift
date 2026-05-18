import AppKit
import Highlightr
import NotesCore
import SwiftUI

/// コードブロックの編集ビュー（F-EDIT-04）。言語指定とシンタックスハイライトを提供する。
struct CodeBlockEditor: View {
    @Binding var block: CodeBlock

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .foregroundStyle(.secondary)
                TextField("言語（例: swift, python）", text: languageBinding)
                    .textFieldStyle(.plain)
                    .font(.caption)
                    .frame(maxWidth: 220)
            }
            CodeEditorView(code: $block.code, language: block.language)
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.quaternary)
                )
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { block.language ?? "" },
            set: { block.language = $0.isEmpty ? nil : $0 }
        )
    }
}

/// `Highlightr` を用いた、シンタックスハイライト付きのコード編集 `NSTextView` ラッパー。
struct CodeEditorView: NSViewRepresentable {
    @Binding var code: String
    var language: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(code: $code)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textStorage = CodeAttributedString()
        textStorage.language = language
        textStorage.highlightr.setTheme(to: "xcode")

        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer()
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        let textView = NSTextView(frame: .zero, textContainer: textContainer)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.drawsBackground = false
        textView.string = code

        let scrollView = NSScrollView()
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if let storage = textView.textStorage as? CodeAttributedString, storage.language != language {
            storage.language = language
        }
        if textView.string != code {
            textView.string = code
        }
    }

    /// `NSTextView` の編集を `code` バインディングへ反映するコーディネータ。
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let code: Binding<String>

        init(code: Binding<String>) {
            self.code = code
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            code.wrappedValue = textView.string
        }
    }
}
