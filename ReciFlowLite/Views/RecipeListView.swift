import SwiftUI

struct RecipeListView: View {
    @ObservedObject var store: RecipeStore
    @Binding var path: [Route]

    var body: some View {
        List {
            ForEach(store.recipes) { recipe in
                Button {
#if DEBUG
   let t0 = CFAbsoluteTimeGetCurrent()
   print("[DEBUG] tap row start", recipe.id)
   #endif
                    path.append(.edit(recipe.id))
#if DEBUG
   print("[DEBUG] tap row end", CFAbsoluteTimeGetCurrent() - t0)
   #endif
                } label: {
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(recipe.title.isEmpty ? "New Recipe" : recipe.title)
                                .font(.headline)
                            Text("Updated: \(recipe.updatedAt.formatted(date: .numeric, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0) // ← これが「右側まで当たり判定」を作る決定打
                    }
                    .padding(.vertical, 16)
                    .contentShape(Rectangle()) // ← “行全体”を当たり判定に
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)) // ← ここに置く
            }
        }

        .overlay(alignment: .bottomTrailing) { // ✅ List全体に1個だけ
            Button {
                let newId = store.addNewRecipeAndPersist()
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
