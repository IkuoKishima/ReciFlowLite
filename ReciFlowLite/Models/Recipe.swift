//❶一件のレコード、例えるなら爪楊枝一本

import Foundation

struct Recipe: Identifiable, Hashable {
    let id: UUID // レシピ固有ID
    var title: String // レシピタイトル
//    var ingredients: [IngredientItem] // 材料を繋げる
    
    init(id: UUID = UUID(), title: String) {
        self.id = id
        self.title = title
    }
}
