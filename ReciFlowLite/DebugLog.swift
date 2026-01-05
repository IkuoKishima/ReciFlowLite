/// MARK: - DebugLog.swift

import Foundation

@inline(__always)
func DBLOG(
    _ items: Any...,
    file: String = #fileID,
    line: Int = #line
) {
    #if DEBUG
    let msg = items.map { String(describing: $0) }.joined(separator: " ")
    print("DBLOG:", msg, "(\(file):\(line))")
    #endif
}
