/// MARK: - ExportFileWriter.swift

import Foundation

enum ExportFileWriter {

    private static func safeTimestampForFilename(_ date: Date = Date()) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: date)
    }

    // ✅ 互換用：古い呼び名を残す（中身は新実装へ）
        static func writeTempExportFile(data: Data) throws -> URL {
            try writeExportFileToDocuments(data: data)
        }

        // ✅ 本命：Documents/Exports に保存（消えにくい）
        static func writeExportFileToDocuments(data: Data) throws -> URL {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = TimeZone(secondsFromGMT: 0)
            f.dateFormat = "yyyyMMdd_HHmmss"
            let ts = f.string(from: Date())

            let name = "ReciFlowLite_export_\(ts).json"

            let fm = FileManager.default
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let dir = docs.appendingPathComponent("Exports", isDirectory: true)

            if fm.fileExists(atPath: dir.path) == false {
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }

            let url = dir.appendingPathComponent(name)
            try data.write(to: url, options: [.atomic])
            return url
        }

    /// ✅ 任意：古いExportを掃除（例：最新N個だけ残す）
    static func cleanupOldExports(keepLatest count: Int = 10) {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Exports", isDirectory: true)

        guard let files = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let jsons = files.filter { $0.pathExtension.lowercased() == "json" }
        let sorted = jsons.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return da > db
        }

        let toDelete = sorted.dropFirst(count)
        for u in toDelete { try? fm.removeItem(at: u) }
    }
}
