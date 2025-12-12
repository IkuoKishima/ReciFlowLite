//❷メモリ上に書かれた爪楊枝、束ねられた状態＋その束を操作するためのリモコン・どう操作するかを処理

import Foundation
import SwiftUI

final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    init() {
        self.recipes = [
            Recipe(title: "豚の角煮"),
            Recipe(title: "鶏の照り焼き"),
            Recipe(title: "鮭の塩焼き")
        ]
    }
    
    func addEmptyRecipe() {
        let new = Recipe(title: "New Recipe")
        recipes.append(new)
    }
}
extension RecipeStore {
    static var preview: RecipeStore {
        let s = RecipeStore()
        return s
    }
}
