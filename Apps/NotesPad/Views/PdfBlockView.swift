import NotesCore
import PDFKit
import SwiftUI
import UIKit

/// PDF ブロックのインライン表示カード（F-PDF-02）。
///
/// 先頭ページのサムネイルと概要を示し、タップで全体表示シートを開く。
struct PadPdfCard: View {
    let pdf: PdfBlock

    @State private var isPresentingViewer = false

    var body: some View {
        Button {
            isPresentingViewer = true
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(pdf.caption.isEmpty ? "PDF" : pdf.caption)
                        .font(.headline)
                        .lineLimit(2)
                    Text(pdf.isEmpty ? "PDF が読み込まれていません" : "\(pdf.pageCount) ページ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(pdf.isEmpty)
        .sheet(isPresented: $isPresentingViewer) {
            PadPdfViewerView(pdf: pdf)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = PdfPreview.firstPageImage(from: pdf.documentData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 72)
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(.quaternary))
        } else {
            Image(systemName: "doc.richtext")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 72)
        }
    }
}

/// PDF を複数ページ・サムネイル一覧付きで全体表示するシート（F-PDF-02）。
struct PadPdfViewerView: View {
    let pdf: PdfBlock

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PadPdfDocumentView(data: pdf.documentData)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(pdf.caption.isEmpty ? "PDF" : pdf.caption)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("閉じる") { dismiss() }
                    }
                }
        }
    }
}

/// `PDFView` とサムネイル一覧を組み合わせた PDF 表示ビュー（F-PDF-02）。
struct PadPdfDocumentView: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> UIView {
        let container = UIView()

        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(data: data)
        pdfView.translatesAutoresizingMaskIntoConstraints = false

        let thumbnailView = PDFThumbnailView()
        thumbnailView.pdfView = pdfView
        thumbnailView.thumbnailSize = CGSize(width: 80, height: 110)
        thumbnailView.layoutMode = .vertical
        thumbnailView.backgroundColor = .secondarySystemBackground
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(thumbnailView)
        container.addSubview(pdfView)
        NSLayoutConstraint.activate([
            thumbnailView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            thumbnailView.topAnchor.constraint(equalTo: container.topAnchor),
            thumbnailView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 116),
            pdfView.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),
            pdfView.topAnchor.constraint(equalTo: container.topAnchor),
            pdfView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            pdfView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

/// PDF の先頭ページをサムネイル画像へ描画するヘルパー。
enum PdfPreview {
    static func firstPageImage(from data: Data) -> UIImage? {
        guard !data.isEmpty,
              let document = PDFDocument(data: data),
              let page = document.page(at: 0) else { return nil }
        return page.thumbnail(of: CGSize(width: 160, height: 206), for: .mediaBox)
    }
}

/// `fileImporter` で選択した PDF ファイルから `PdfBlock` を生成するヘルパー（F-PDF-01）。
///
/// 全文検索（F-PDF-08）のため、取り込み時に PDFKit で本文テキストを抽出して保持する。
enum PdfImport {
    static func makeBlock(from url: URL) -> PdfBlock? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let document = PDFDocument(data: data) else { return nil }

        let extractedText = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
        return PdfBlock(documentData: data,
                        caption: url.deletingPathExtension().lastPathComponent,
                        pageCount: document.pageCount,
                        extractedText: extractedText)
    }
}
