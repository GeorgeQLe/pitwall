import AppKit
import SwiftUI

struct DiagnosticsExportView: View {
    let onExport: () async -> String

    @State private var exportedText = ""
    @State private var message: String?
    @State private var isExporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Diagnostics Export")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Button(action: export) {
                    Image(systemName: "doc.on.doc")
                }
                .help("Export redacted diagnostics")
                .disabled(isExporting)
            }

            if exportedText.isEmpty {
                Text("Exported diagnostics include provider status, confidence, storage health, and redacted event summaries.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView {
                    Text(exportedText)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 140)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if let message {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func export() {
        Task {
            isExporting = true
            defer { isExporting = false }

            let text = await onExport()
            exportedText = text

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            message = "Redacted diagnostics copied."
        }
    }
}
