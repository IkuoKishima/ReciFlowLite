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
                            store: store.engineStore(for: id),
                            onPrimary: {
                                print("<<< back tapped (primary)")
                                guard !path.isEmpty else { return }
                                path.removeLast()
                            },
                            onHome: { path = [] },
                            onSwipeLeft: { },
                            onSwipeRight: {
                                print("<<< back swiped (rail)")
                                guard !path.isEmpty else { return }
                                path.removeLast()
                            },
                            onDelete: { }
                        )
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
