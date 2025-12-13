import SwiftUI

struct RecipeEditView: View {
    @ObservedObject var store: RecipeStore
    let recipeId: UUID
    @Binding var path: [Route]

    @State private var title: String = ""
    @State private var memo: String = ""

    var body: some View {
        let recipe = store.recipe(for: recipeId)

        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $memo)
                .frame(minHeight: 140)
                .overlay(alignment: .topLeading) {
                    if memo.isEmpty {
                        Text("Memo")
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                }
                .padding(.horizontal, -4)

            if let r = recipe {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Created: \(r.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    Text("Updated: \(r.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(16)
        .navigationTitle("Edit")
        .onAppear {
            // 初期表示に反映
            if let r = recipe {
                title = r.title
                memo  = r.memo
            }
        }
        // 変更を即反映（Liteなのでシンプルに）
        .onChange(of: title) { _, newValue in
            store.updateRecipeMeta(recipeId: recipeId, title: newValue, memo: memo)
        }
        .onChange(of: memo) { _, newValue in
            store.updateRecipeMeta(recipeId: recipeId, title: title, memo: newValue)
        }
        .overlay {
            RightRailControls(
                mode: .forward,
                onPrimary: {
                    path.append(.engine(recipeId))      // > でも進める
                },
                onHome: {
                    path = []                           // 🔳 でリストへ
                },
                onSwipeLeft: {
                    path.append(.engine(recipeId))      // 右→左で進む
                },
                onSwipeRight: {
                    // Editで右スワイプは何もしない（誤爆防止）
                }
            )
        }

    }
}

// MARK: - プレビュー

////下の書き方は使えるが、データベースと連携で初期レコードゼロならXcodeエラーも出た
//#Preview {
//    let store = RecipeStore.preview
//    return NavigationStack {
//        RecipeEditView(
//            store: store,
//            recipeID: store.recipes[0].id //レシピid[0]で必ずあるので表示できる
//        )
//    }
//}
