//❷メモリ上に書かれた爪楊枝、束ねられた状態＋その束を操作するためのリモコン・どう操作するかを処理

import Foundation
import SwiftUI


final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []

    init() {
        recipes = DatabaseManager.shared.fetchAllRecipes()
    }

    func recipe(for id: UUID) -> Recipe? {
        recipes.first(where: { $0.id == id })
    }

    @discardableResult
    func addNewRecipeAndPersist() -> UUID {
        let now = Date()
        let title = "New \(now.formatted(date: .numeric, time: .shortened))"

        let new = Recipe(
            id: UUID(),
            title: title,
            memo: "",
            createdAt: now,
            updatedAt: now
        )

        recipes.insert(new, at: 0)
        DatabaseManager.shared.insert(recipe: new)
        return new.id
    }

    func updateRecipeMeta(recipeId: UUID, title: String, memo: String) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        recipes[idx].title = title.isEmpty ? "New Recipe" : title
        recipes[idx].memo = memo
        recipes[idx].updatedAt = Date()

        DatabaseManager.shared.update(recipe: recipes[idx])
    }
}

extension RecipeStore {
    static var preview: RecipeStore {
        let s = RecipeStore()
        return s
    }
}
