//🟨 ここを司令塔にする(状態を持っているのはここ、Viewは参照しているだけ）

import Foundation

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []

    private(set) var parentRecipeId: UUID

    init(parentRecipeId: UUID) {
        self.parentRecipeId = parentRecipeId
    }

    // MARK: - 読込
    
    func loadIfNeeded() {
        #if DEBUG
        print("🟦 loadIfNeeded start recipeId=\(parentRecipeId)")
        #endif

        if !rows.isEmpty {
            #if DEBUG
            print("🟦 loadIfNeeded early return (rows already exist) count=\(rows.count)")
            #endif
            return
        }

        DatabaseManager.shared.createIngredientTablesIfNeeded()

        #if DEBUG
        print("🟦 fetchIngredientRows start")
        #endif

        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)

        #if DEBUG
        print("🟦 fetchIngredientRows end count=\(loaded.count)")
        #endif
        if !loaded.isEmpty {
            rows = loaded
            return
        }

        // v1: 初回だけ最小の種
        let block = IngredientBlock(
            parentRecipeId: parentRecipeId,
            orderIndex: 2,
            title: "合わせ調味料"
        )

        rows = [
            .single(.init(parentRecipeId: parentRecipeId, name: "酒", amount: "012345", unit: "ml")),
            .single(.init(parentRecipeId: parentRecipeId, name: "醤油", amount: "15", unit: "0123")),

            .blockHeader(block),

            .blockItem(.init(
                parentRecipeId: parentRecipeId,
                parentBlockId: block.id,     // ✅ 束に属する
                name: "砂糖", amount: "012345", unit: "0123"
            )),
            .blockItem(.init(
                parentRecipeId: parentRecipeId,
                parentBlockId: block.id,     // ✅ 束に属する
                name: "塩", amount: "1", unit: "tsp"
            )),

            .single(.init(parentRecipeId: parentRecipeId, name: "塩", amount: "1", unit: "tsp")),
            .single(.init(parentRecipeId: parentRecipeId, name: "", amount: "", unit: ""))
        ]
    }


    // MARK: - 保存
    
    func saveNow() {
        DatabaseManager.shared.createIngredientTablesIfNeeded()
        DatabaseManager.shared.replaceIngredientRows(
            recipeId: parentRecipeId,
            rows: rows
        )
        //保存した責任側がログを出す方が好まれる書き方
        #if DEBUG
        print("✅ saved \(rows.count) rows")
        #endif
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




