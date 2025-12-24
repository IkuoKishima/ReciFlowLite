import SwiftUI

struct ContentView: View {
    @StateObject private var recipeStore = RecipeStore()
    @StateObject private var store = RecipeStore()
    @State private var path: [Route] = []

    @State private var showLaunchOverlay = true
    @State private var minimumDisplayFinished = false

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                    RecipeListView(store: recipeStore, path: $path)
                        .navigationDestination(for: Route.self) { route in
                            switch route {

                            case .edit(let id):
                                RecipeEditView(
                                    store: recipeStore,
                                    recipeId: id,
                                    path: $path
                                )

                            case .engine(let id):
                                IngredientEngineView(
                                    recipeTitle: recipeStore.recipes
                                        .first(where: { $0.id == id })?.title ?? "Menu",
                                    recipeStore: recipeStore,
                                    store: recipeStore.engineStore(for: id),
                                    onPrimary: { path.removeLast() },
                                    onHome: { path = [] },
                                    onSwipeLeft: { },
                                    onSwipeRight: { path.removeLast() },
                                    onDelete: { }
                                )
                            }
                        }
                }

            if showLaunchOverlay {
                LoadingView(
                    imageName: "loading_kitchen_notebook",
                    title: "ReciFlow",
                    isLoading: .constant(true)
                )
                .transition(.opacity)
                .zIndex(1000)
            }
        }
        .onAppear {
            // ⏱ 最小表示時間（ここが肝）
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                minimumDisplayFinished = true
                evaluateLaunchOverlay()
            }
        }
        .onChange(of: store.isLoading) { _, _ in
            evaluateLaunchOverlay()
        }
    }

    private func evaluateLaunchOverlay() {
        // ロード完了 AND 最小時間経過
        if !store.isLoading && minimumDisplayFinished {
            withAnimation(.easeOut(duration: 0.35)) {
                showLaunchOverlay = false
            }
        }
    }
}

#Preview {
    ContentView()
}
