import Foundation
import AppKit
import PDFKit
import UniformTypeIdentifiers

struct FilePreview {
    let fileName: String
    let image: NSImage?
    let text: String?
    let fileType: UTType?
}

class PreviewManager: ObservableObject {
    @Published var previews: [String: FilePreview] = [:]
    private let fileManager = FileManager.default
    private let previewQueue = DispatchQueue(label: "com.terminalplus.previewmanager", qos: .userInitiated)

    func getPreview(for path: String) -> FilePreview? {
        // Return cached preview if available
        if let cached = previews[path] {
            return cached
        }

        // Generate preview asynchronously to avoid blocking
        previewQueue.async { [weak self] in
            guard let self = self else { return }

            // Expand path and check if file exists
            let expandedPath = NSString(string: path).expandingTildeInPath
            guard self.fileManager.fileExists(atPath: expandedPath) else { return }

            let url = URL(fileURLWithPath: expandedPath)
            let fileName = url.lastPathComponent

            // Determine file type
            guard let fileType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return
            }

            var preview: FilePreview?

            // Handle images
            if fileType.conforms(to: .image) {
                if let image = NSImage(contentsOf: url) {
                    preview = FilePreview(fileName: fileName, image: image, text: nil, fileType: fileType)
                }
            }
            // Handle PDFs
            else if fileType.conforms(to: .pdf) {
                if let pdfDocument = PDFDocument(url: url),
                   let firstPage = pdfDocument.page(at: 0) {
                    let thumbnail = firstPage.thumbnail(of: NSSize(width: 300, height: 300), for: .mediaBox)
                    preview = FilePreview(fileName: fileName, image: thumbnail, text: nil, fileType: fileType)
                }
            }
            // Handle text files
            else if fileType.conforms(to: .text) || fileType.conforms(to: .sourceCode) {
                if let text = try? String(contentsOf: url, encoding: .utf8) {
                    let truncatedText = String(text.prefix(500))
                    preview = FilePreview(fileName: fileName, image: nil, text: truncatedText, fileType: fileType)
                }
            }
            // Handle JSON
            else if fileType.conforms(to: .json) {
                if let data = try? Data(contentsOf: url),
                   let json = try? JSONSerialization.jsonObject(with: data),
                   let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    let truncated = String(prettyString.prefix(500))
                    preview = FilePreview(fileName: fileName, image: nil, text: truncated, fileType: fileType)
                }
            }

            // Cache the preview on main thread
            if let preview = preview {
                DispatchQueue.main.async {
                    self.previews[path] = preview
                }
            }
        }

        return nil
    }

    func clearCache() {
        DispatchQueue.main.async { [weak self] in
            self?.previews.removeAll()
        }
    }

    func removePreview(for path: String) {
        DispatchQueue.main.async { [weak self] in
            self?.previews.removeValue(forKey: path)
        }
    }
}

// Helper extension to detect file paths in terminal output
extension String {
    func extractFilePaths() -> [String] {
        // Common file path patterns
        let patterns = [
            // Absolute paths
            #"(/[a-zA-Z0-9._/-]+)"#,
            // Relative paths
            #"(\./[a-zA-Z0-9._/-]+)"#,
            #"(\.\./[a-zA-Z0-9._/-]+)"#,
            // Home directory paths
            #"(~/[a-zA-Z0-9._/-]+)"#
        ]

        var paths: [String] = []

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(self.startIndex..., in: self)
                let matches = regex.matches(in: self, range: range)

                for match in matches {
                    if let range = Range(match.range(at: 1), in: self) {
                        let path = String(self[range])
                        paths.append(path)
                    }
                }
            }
        }

        return paths
    }
}
