import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecipeStore()
    @State private var path: [Route] = [] //ナビゲーションルーター用

    var body: some View {
        NavigationStack(path: $path) {
            RecipeListView(store: store, path: $path)
                .navigationDestination(for: Route.self) { route in
                    
                    
                    switch route {
                        
                    case .edit(let id):
                        RecipeEditView(
                            store: store,
                            recipeId: id,
                            path: $path
                        )

                    
                    //✅ここでエンジンビューを生成している
                    case .engine(let id):
                        IngredientEngineView(
                            engineStore: store.engineStore(for: id),
                            recipeStore: store,
                            recipeId: id,
                            path: $path
                        )
                        
                        
                        
                        

                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
