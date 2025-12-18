#if DEBUG
import SwiftUI

private struct IngredientEnginePreviewContainer: View {
    @StateObject private var recipeStore = RecipeStore.previewStore()
    @State private var path: [Route] = []
    private let recipeId = UUID()

    var body: some View {
        IngredientEngineView(
            engineStore: .previewStore(),
            recipeStore: recipeStore,
            recipeId: recipeId,
            path: $path
        )
    }
}

#Preview {
    NavigationStack {
        IngredientEnginePreviewContainer()
    }
}
#endif
