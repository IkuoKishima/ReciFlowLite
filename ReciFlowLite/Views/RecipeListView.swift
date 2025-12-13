import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    @Binding var path: [Route]

    var body: some View {
        List {
            ForEach(store.recipes) { recipe in
                Button {
                    path.append(.edit(recipe.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title.isEmpty ? "New Recipe" : recipe.title)
                            .font(.headline)

                        Text("Updated: \(recipe.updatedAt.formatted(date: .numeric, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("ReciFlowLite")
        .overlay(alignment: .bottomTrailing) {
            Button {
                let newId = store.addNewRecipeAndPersist() // ←下でRecipeStoreに追加する
                path.append(.edit(newId))
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .padding(.trailing, 18)
            .padding(.bottom, 18)
        }
    }
}


//#Preview {
//    NavigationStack {
//        RecipeListView(
//            store: .preview
//        )
//    }
//}
