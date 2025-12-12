//import Foundation
//
//struct IngredientItem: Identifiable, Equatable, Codable, Hashable {
//    let id: UUID // 材料固有ID
//    var name: String
//    var amount: String
//    var unit: String
//    var pearentRecipeId: UUID //親レシピは誰かを格納
//    var pearentBookId: UUID?  //どのブロック（合わせ調味料）単体行ブロック外ならnil (?)無いかもオプショナル
//    var orderIndex: Int //レシピの並び順(0,1,2)画面の見える順
//    
//    
//    init(
//        id: UUID = UUID(),
//        name: String = "",
//        amount: String = "",
//        unit: String = "",
//        pearentRecipeId: UUID,
//        pearentBookId: UUID? = nil,
//        orderIndex: Int = 0
//    ) {
//        self.id = id
//        self.name = name
//        self.amount = amount
//        self.unit = unit
//        self.pearentRecipeId = pearentRecipeId
//        self.pearentBookId = pearentBookId
//        self.orderIndex = orderIndex
//    }
//}
