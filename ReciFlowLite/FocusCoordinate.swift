/// MARK: - FocusCoordinate.swift

import Foundation

struct FocusCoordinate: Equatable { //これが router.current の中身
    enum Field: Int, CaseIterable { case name = 0, amount = 1, unit = 2 }
    let rowId: UUID
    let field: Field
}
