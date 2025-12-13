//❷メモリ上に書かれた爪楊枝、束ねられた状態＋その束を操作するためのリモコン・どう操作するかを処理

import Foundation
import SwiftUI

final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    //    init() {
    //        self.recipes = [
    //            Recipe(title: "豚の角煮"),
    //            Recipe(title: "鶏の照り焼き"),
    //            Recipe(title: "鮭の塩焼き")
    //        ]
    //    }
    init() {
        // 起動時に DB から読み込む
        recipes = DatabaseManager.shared.fetchAllRecipes()
    }
    
    func addEmptyRecipe() {
        let now = Date()
        let new = Recipe(
            id: UUID(),
            title: "",
            memo: "",
            createdAt: now,
            updatedAt: now
        )
        recipes.insert(new, at: 0)
        DatabaseManager.shared.insert(recipe: new)
    }
    
    func update(_ recipe: Recipe) {
        guard let index = recipes.firstIndex(where: { $0.id == recipe.id }) else { return }
        recipes[index] = recipe
        DatabaseManager.shared.update(recipe: recipe)
    }
    
    func delete(at offsets: IndexSet) {
        for index in offsets {
            let recipe = recipes[index]
            DatabaseManager.shared.delete(recipeID: recipe.id)
        }
        recipes.remove(atOffsets: offsets)
    }
}
extension RecipeStore {
    static var preview: RecipeStore {
        let s = RecipeStore()
        return s
    }
}
