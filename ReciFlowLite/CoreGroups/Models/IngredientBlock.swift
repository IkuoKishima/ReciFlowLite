/// MARK: - IngredientBlock.swift

import Foundation

struct IngredientBlock: Identifiable, Equatable, Codable {
    let id: UUID
    var parentRecipeId: UUID
    var orderIndex: Int
    var title: String

    init(
        id: UUID = UUID(),
        parentRecipeId: UUID,
        orderIndex: Int = 0,
        title: String = ""
    ) {
        self.id = id
        self.parentRecipeId = parentRecipeId
        self.orderIndex = orderIndex
        self.title = title
    }
}
