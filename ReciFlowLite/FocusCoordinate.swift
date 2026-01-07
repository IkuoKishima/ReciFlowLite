/// MARK: - FocusCoordinate.swift

import Foundation

struct FocusCoordinate: Equatable {
    enum Field: Int, CaseIterable { case name = 0, amount = 1, unit = 2 }
    let rowId: UUID
    let field: Field
}
