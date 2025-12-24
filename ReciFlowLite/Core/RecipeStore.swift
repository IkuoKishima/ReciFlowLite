/// MARK: - RecipeStore.swift

//メモリ上に書かれた爪楊枝、束ねられた状態＋その束を操作するためのリモコン・どう操作するかを処理

import Foundation
import SwiftUI
import Combine //⚠️ObservableObjectと@Published を使ったら必須


// MARK: - 型・クラス（class）
@MainActor
final class RecipeStore: ObservableObject {
    
    
    // MARK: - 🟨プロパティ（property）その物が持っているメモリ上の状態・値
    
    @Published var recipes: [Recipe] = []
    @Published var isLoading: Bool = false
    @Published var pendingUndo: Recipe? = nil //1件Undoのために追記
    private var engineStores: [UUID: IngredientEngineStore] = [:]
 
    
    
    // MARK: - 🟨イニシャライザ（initializer / init）“RecipeStoreが生まれた瞬間に、レシピを読み込む” という初期動作
    init() {
            loadRecipes()
    }
   
    
    
    // MARK: - 🟨　メソッド（method）挙動　その物ができる行動（処理・手順）
    
    // 材料更新で更新日時だけ更新
    func touchRecipeUpdatedAt(_ recipeId: UUID) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }

        recipes[idx].updatedAt = Date()
        DatabaseManager.shared.update(recipe: recipes[idx])
    }
    
    
    
    //読み込み系API
   
    func loadRecipes() {
        isLoading = true
        Task {
            let fetched = await DatabaseManager.shared.fetchAllRecipes()
            self.recipes = fetched
            self.isLoading = false
        }
    }


    //参照系API
    func recipe(for id: UUID) -> Recipe? {
        recipes.first(where: { $0.id == id })
    }
    
    
    

    // 削除/追加（書き換える挙動 IndexSet）を受ける関数
    
    func requestDelete(at offsets: IndexSet) {
        guard let index = offsets.first, recipes.indices.contains(index) else { return }
        let target = recipes[index]

        // 1) まずUI上から消す（体感を良くする）
        recipes.remove(at: index)

        // 2) 直前削除として保持（1件だけ）
        pendingUndo = target

        // 3) DBは論理削除
        DatabaseManager.shared.softDelete(recipeID: target.id)
    }
    
    
    func undoDelete() {
        guard let r = pendingUndo else { return }
        pendingUndo = nil

        // 1) DB復元
        DatabaseManager.shared.restore(recipeID: r.id)

        // 2) UIに戻す（先頭に戻すでOK / index復元は後で良い）
        recipes.insert(r, at: 0)
    }
    
    


    //「engineStore辞書」を追加
    func engineStore(for recipeId: UUID) -> IngredientEngineStore {
        if let existing = engineStores[recipeId] { return existing }
        let store = IngredientEngineStore(parentRecipeId: recipeId)
        engineStores[recipeId] = store
        return store
    }
    
    
    @discardableResult
    func addNewRecipeAndPersist() async -> UUID {
        let now = Date()
        let title = "" //足されるものに日付と時間を追加している

        let new = Recipe(
            id: UUID(),
            title: title,
            memo: "",
            createdAt: now,
            updatedAt: now
        )
        recipes.insert(new, at: 0) // ここの書き換えで先頭追加から末尾追加に変わる、リストの性質上上から下表示なので、ここで変更せずクエリで抽出にする

        await DatabaseManager.shared.insert(recipe: new)
        return new.id
    }

    
    
    // 方針: Liteではオートセーブを優先（中断しても損失ゼロ）。
    // ただし「変更があった時だけ」DB更新し、無駄な updatedAt 更新を避ける。
    // viewedAt / debounce はレコード増加・体感が出た段階で導入検討。

    func updateRecipeMeta(recipeId: UUID, title: String, memo: String) {
        guard let idx = recipes.firstIndex(where: { $0.id == recipeId }) else { return }
        let newTitle = title.isEmpty ? "New" : title
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
