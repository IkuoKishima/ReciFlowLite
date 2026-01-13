/// MARK: - ContentView.swift

import SwiftUI

struct ContentView: View {
    @StateObject private var store = RecipeStore()
    @State private var path: [Route] = []

    @State private var showLaunchOverlay = true
    @State private var minimumDisplayFinished = false

    var body: some View {
        ZStack {
            NavigationStack(path: $path) {
                RecipeListView(store: store, path: $path)
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .edit(let id):
                            RecipeEditView(store: store, recipeId: id, path: $path)

                        case .engine(let id):
                            IngredientEngineView(
                                recipeTitle: store.recipes.first(where: { $0.id == id })?.title ?? "Menu",
                                recipeStore: store,
                                store: store.engineStore(for: id),
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
