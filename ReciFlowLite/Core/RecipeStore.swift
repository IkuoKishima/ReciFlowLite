//❷メモリ上に書かれた爪楊枝、束ねられた状態＋その束を操作するためのリモコン・どう操作するかを処理

import Foundation
import SwiftUI


final class RecipeStore: ObservableObject {
    @Published var recipes: [Recipe] = []
    
    private var engineStores: [UUID: IngredientEngineStore] = [:]
    
    // MARK: - 初期化

    init() {
        recipes = DatabaseManager.shared.fetchAllRecipes()
    }

    func recipe(for id: UUID) -> Recipe? {
        recipes.first(where: { $0.id == id })
    }

    @discardableResult
    
    
    // MARK: - ファンクションの集まり
    
    //「engineStore辞書」を追加
    func engineStore(for recipeId: UUID) -> IngredientEngineStore {
        if let s = engineStores[recipeId] { return s }
        let s = IngredientEngineStore()
        engineStores[recipeId] = s
        return s
    }
    
    
    
    func addNewRecipeAndPersist() -> UUID {
        let now = Date()
        let title = "New" //足されるものに日付と時間を追加している

        let new = Recipe(
            id: UUID(),
            title: title,
            memo: "",
            createdAt: now,
            updatedAt: now
        )
        recipes.insert(new, at: 0) // ここの書き換えで先頭追加から末尾追加に変わる、リストの性質上上から下表示なので、ここで変更せずクエリで抽出にする

        DatabaseManager.shared.insert(recipe: new)
        return new.id
    }

    
    
    // 方針: Liteではオートセーブを優先（中断しても損失ゼロ）。
    // ただし「変更があった時だけ」DB更新し、無駄な updatedAt 更新を避ける。
    // viewedAt / debounce はレコード増加・体感が出た段階で導入検討。

    func updateRecipeMeta(recipeId: UUID, title: String, memo: String) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        let newTitle = title.isEmpty ? "New Recipe" : title
        let newMemo  = memo

        let hasChanged =
            recipes[idx].title != newTitle ||
            recipes[idx].memo  != newMemo

        guard hasChanged else { return }   // 内容が変わった時だけタイムスタンプ更新

        recipes[idx].title = newTitle
        recipes[idx].memo  = newMemo
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
