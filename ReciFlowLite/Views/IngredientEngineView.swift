import SwiftUI

struct IngredientEngineView: View {
    @ObservedObject var store: RecipeStore
    let recipeId: UUID
    @Binding var path: [Route]

    var body: some View {
        ZStack {
            // ここにエンジン（最小）を置く
            VStack(alignment: .leading, spacing: 12) {
                
                Text("Ingredient Engine")
                    .font(.title2.weight(.semibold))
                
                

                Text("（Day2は動線優先。エンジン本体はここに実装していく）")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .navigationBarBackButtonHidden(true) // 🍎標準左上の戻るが自動生成されている時、消してねと頼む記述
            .padding(16)
            
            //🟨ここで共通のページめくり関数と繋げ行き来の速度を速くする
            .overlay {
                RightRailControls(
                    mode: .back,
                    onPrimary: {
                        if !path.isEmpty { path.removeLast() }  // < でも戻れる
                    },
                    onHome: {
                        path = []                                // 🔳でリストへ
                    },
                    onSwipeLeft: {
                        // Engineで左スワイプは何もしない（誤爆防止）
                    },
                    onSwipeRight: {
                        if !path.isEmpty { path.removeLast() }   // 左→右で戻る
                    }
                )
            }
            
            

        }
        .navigationTitle("Ingredients")
    }
}
