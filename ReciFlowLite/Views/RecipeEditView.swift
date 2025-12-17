import SwiftUI

struct RecipeEditView: View {
    @ObservedObject var store: RecipeStore
    let recipeId: UUID
    @Binding var path: [Route]

    @State private var title: String = ""
    @State private var memo: String = ""
    
    
    @State private var isDeleteMode = false
    
#if DEBUG
private static func _debugBodyTick() -> Bool {
    print("[DEBUG] Edit body tick")
    return true
}
#endif


    var body: some View {
#if DEBUG
let _ = Self._debugBodyTick()
#endif

        let recipe = store.recipe(for: recipeId)

        VStack(alignment: .leading, spacing: 12) {

            TextField("Title", text: $title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.roundedBorder)

            //RecipeMetaStripで日付表示を共通化し、コードを簡素化する
            if let r = recipe {
                RecipeMetaStrip(createdAt: r.createdAt, updatedAt: r.updatedAt)
            }
            

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

            Spacer()
        }
        .navigationBarBackButtonHidden(true) // 🍎標準左上の戻るが自動生成されている時、消してねと頼む記述

        .padding(16)
        .navigationTitle("概要")
        .onAppear {
          #if DEBUG
          print("[DEBUG] Edit onAppear start")
          #endif
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
        
        //🟨ここで共通のページめくり関数と繋げ行き来の速度を速くする
        .overlay {
            RightRailControls(
                mode: .forward,
                showsDelete: false,
                showsAdd: false,              // ✅ 追加ボタンは非表示
                
                isDeleteMode: isDeleteMode,
                onToggleDelete: { isDeleteMode.toggle() },
                // 使わないので空でOK（呼ばれない）
                onAddSingle: { },
                onAddBlock: { },
                
                onPrimary: {path.append(.engine(recipeId))},    // > でも進める
                onHome: {path = []},                                // 🔳 でリストへ
                onSwipeLeft: {path.append(.engine(recipeId))},  // 右→左で進む
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
