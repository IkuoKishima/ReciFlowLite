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

    @MainActor
        private func dismissKeyboard() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    
    
    

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
                        Text("作りかた")
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
        .navigationTitle("レシピ名")
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
        .overlay(alignment: .topTrailing) {
            UIKitRightDock(
                mode: .forward,
                showsDelete: false,
                showsAdd: false,
                showsKeyboardDismiss: true,
                isDeleteMode: false,
                onToggleDelete: { },

                onAddSingle: { },
                onAddBlock: { },

                onPrimary: {
                    dismissKeyboard()
                    path.append(.engine(recipeId))
                },
                onHome: {
                    dismissKeyboard()
                    path = []
                },

                onSwipeLeft: {
                    dismissKeyboard()
                    path.append(.engine(recipeId))
                },
                onSwipeRight: { },

                // ✅ ここから「UIKit配置パラメータ」が先
                railWidth: 38,
                buttonSize: 30,
                trailingPadding: 11,
                verticalSpacing: 16,
                centerYRatio: 0.38,
                minBottomPadding: 6,

                // ✅ showsPrimary / showsHome は最後
                showsPrimary: true,
                showsHome: true
            )
            .frame(width: 80)
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }

        

    }
}

