/// MARK: - IngredientRow.swift

import Foundation

enum IngredientRow: Identifiable, Equatable {
    case single(IngredientItem)
    case blockHeader(IngredientBlock)
    case blockItem(IngredientItem)

    var id: UUID {
        switch self {
        case .single(let i): return i.id
        case .blockHeader(let b): return b.id
        case .blockItem(let i): return i.id
        }
    }
}
extension IngredientRow {
    var rowId: UUID {
        switch self {
        case .single(let item):      return item.id
        case .blockItem(let item):   return item.id
        case .blockHeader(let block):return block.id
        }
    }
}
