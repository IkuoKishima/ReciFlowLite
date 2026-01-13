/// MARK: - IngredientItem.swift

import Foundation

struct IngredientItem: Identifiable, Equatable, Codable, Hashable {
    var id: UUID // 材料固有ID
    // ✅ DB保存に必要
    var parentRecipeId: UUID //親レシピは誰かを格納
    var parentBlockId: UUID?  //どのブロック（合わせ調味料）単体行ブロック外ならnil (?)無いかもオプショナル
    var orderIndex: Int //レシピの並び順(0,1,2)画面の見える順
    // 入力
    var name: String
    var amount: String
    var unit: String

    
    init(
        id: UUID = UUID(),
        parentRecipeId: UUID,
        parentBlockId: UUID? = nil,
        orderIndex: Int = 0,
        name: String = "",
        amount: String = "",
        unit: String = ""
    ) {
        self.id = id
        self.parentRecipeId = parentRecipeId
        self.parentBlockId = parentBlockId
        self.orderIndex = orderIndex
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}
