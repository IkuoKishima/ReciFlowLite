/// MARK: - ExportFileWriter.swift

import Foundation

enum ExportFileWriter {
    static func writeTempExportFile(data: Data) throws -> URL {
        let ts = ISO8601DateFormatter().string(from: Date())
        let name = "ReciFlowLite_export_\(ts).json"

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: [.atomic])
        return url
    }
}
