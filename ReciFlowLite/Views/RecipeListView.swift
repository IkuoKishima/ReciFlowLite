import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    
    var body: some View {
        List{
            ForEach(store.recipes) { recipe in
                NavigationLink(recipe.title) {
                    RecipeEditView(store: store, recipeID: recipe.id)
                }
            }
        }
        .navigationTitle("Recipes")
        .toolbar {
            Button {
                store.addEmptyRecipe()
            } label: {
                Image(systemName: "plus.circle")
            }
        }
            
       
    }
}

#Preview {
    NavigationStack {
        RecipeListView(
            store: .preview
        )
    }
}
