import Foundation

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []

    private(set) var parentRecipeId: UUID

    init(parentRecipeId: UUID) {
        self.parentRecipeId = parentRecipeId
    }

    func loadIfNeeded() {
        if !rows.isEmpty { return }
        let block = IngredientBlock(
            parentRecipeId: parentRecipeId,
            orderIndex: 2,
            title: "合わせ調味料"
        )

        DatabaseManager.shared.createIngredientTablesIfNeeded()

        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)
        if !loaded.isEmpty {
            rows = loaded
        } else {
            // v1: 初回だけ最小の種（空でもOKならここ消してOK）
            rows = [
                .single(.init(parentRecipeId: parentRecipeId, name: "酒", amount: "012345", unit: "ml")),
                .single(.init(parentRecipeId: parentRecipeId, name: "醤油", amount: "15", unit: "0123")),
                .blockHeader( block),
                .blockItem(.init(parentRecipeId: parentRecipeId, name: "砂糖", amount: "012345", unit: "0123")),
                .blockItem(.init(parentRecipeId: parentRecipeId, name: "塩", amount: "1", unit: "tsp")),
                .single(.init(parentRecipeId: parentRecipeId, name: "塩", amount: "1", unit: "tsp")),
                .single(.init(parentRecipeId: parentRecipeId, name: "", amount: "", unit: ""))
            ]
        }
    }

    func saveNow() {
        DatabaseManager.shared.createIngredientTablesIfNeeded()
        DatabaseManager.shared.replaceIngredientRows(recipeId: parentRecipeId, rows: rows)
    }
}


//import Foundation
//
//final class IngredientEngineStore: ObservableObject {
//    @Published var rows: [IngredientRow] = []
//    
//    //✅Engineから呼び出す仮データ　seedIfNeeded（必要に応じてタネを撒く）
//    func seedIfNeeded() {
//        if rows.isEmpty {
//            let block = IngredientBlock(
//                id: UUID(),
//                title: "合わせ調味料"
//            )
//            rows = [
//                .single(.init(name: "酒", amount: "012345", unit: "ml")),
//                .single(.init(name: "醤油", amount: "15", unit: "0123")),
//                .blockHeader(block),
//                .blockItem(.init(name: "砂糖", amount: "012345", unit: "0123")),
//                .blockItem(.init(name: "塩", amount: "1", unit: "tsp")),
//                .single(.init(name: "塩", amount: "1", unit: "tsp"))
//            ]
//        }
//    }
//}

//enum IngredientRow: Identifiable, Equatable {
//    case single(IngredientItem)
//    case blockHeader(IngredientBlock)
//    case blockItem(IngredientItem)
//
//    var id: UUID {
//        switch self {
//        case .single(let i): return i.id
//        case .blockHeader(let b): return b.id
//        case .blockItem(let i): return i.id
//        }
//    }
//}

//struct IngredientItem: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var name: String = ""
//    var amount: String = ""
//    var unit: String = ""
//}

//struct IngredientBlock: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var title: String = ""
//}




