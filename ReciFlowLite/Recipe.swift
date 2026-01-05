/// MARK: - Recipe.swift

import Foundation

struct Recipe: Identifiable, Hashable {
    let id: UUID // レシピ固有ID
    var title: String // レシピタイトル
    var memo: String // 備考
    var createdAt: Date // 作成日
    var updatedAt: Date // 更新日
//    var ingredients: [IngredientItem] // 材料を繋げる
    
    init(
        id: UUID = UUID(),
        title: String,
        memo: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
