import SwiftUI

struct RecipeEditView: View {
    @ObservedObject var store: RecipeStore
    let recipeID: UUID
    
    private var recipeBinding: Binding<Recipe> {
        guard let index = store.recipes.firstIndex(where: { $0.id == recipeID }) else {
            fatalError("Recipe not found")
        }
        return $store.recipes[index]
    }
    var body: some View {
        Form {
            Section(header: Text("Title")) {
                TextField("レシピ名", text: recipeBinding.title)
            }
            
            Section(header: Text("Ingredients")) {
                Text("※ ここに後で IngredientEditView を実装")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Edit")
    }
}
// MARK: - プレビュー
#Preview {
    let store = RecipeStore.preview
    return NavigationStack {
        RecipeEditView(
            store: store,
            recipeID: store.recipes[0].id //レシピid[0]で必ずあるので表示できる
        )
    }
}
