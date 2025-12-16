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
//
//enum IngredientRow: Identifiable, Equatable {
//    case single(IngredientItem)
//    case blockHeader(IngredientBlock)
//    case blockItem(IngredientItem)
//
//    var id: UUID {
//        switch self {
//        case .single(let item): return item.id
//        case .blockHeader(let block): return block.id
//        case .blockItem(let item): return item.id
//        }
//    }
//}
//
//struct IngredientItem: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var name: String = ""
//    var amount: String = ""
//    var unit: String = ""
//}
//
//struct IngredientBlock: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var title: String = ""
//}
