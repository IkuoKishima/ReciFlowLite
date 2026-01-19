/// MARK: - FocusCoordinate.swift
import Foundation

struct FocusCoordinate: Equatable {
    enum Field: Int, CaseIterable {
        case name = 0
        case amount = 1
        case unit = 2

        // ブロックタイトル（レールには含めないが、フォーカス座標として扱う）
        case headerTitle = 3
    }

    let rowId: UUID
    let field: Field
}
