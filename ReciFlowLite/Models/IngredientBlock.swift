/// MARK: - IngredientBlock.swift
import Foundation

struct IngredientBlock: Identifiable, Equatable {
    var id: UUID = UUID()

    // ✅ DB保存に必要
    var parentRecipeId: UUID
    var orderIndex: Int = 0

    // 入力
    var title: String = ""
}

//struct IngredientBlock: Identifiable,Equatable, Codable {
//    let id: UUID
//    var parentRecipeId: UUID // 親レシピは誰か？
//    var orderIndex: Int  // レシピ内のの並び順、このブロックヘッダーが何行目に出てくるかを記録
//    var title: String // ブロック名は必ず「あり」にすることで、ぶら下りitem無しで扱える
//    
//    init(
//        id: UUID = UUID(),
//        parentRecipeId: UUID,
//        orderIndex: Int = 0,
//        title: String = ""
//    ) {
//        self.id = id
//        self.parentRecipeId = parentRecipeId
//        self.orderIndex = orderIndex
//        self.title = title
//    }
//    
//}
