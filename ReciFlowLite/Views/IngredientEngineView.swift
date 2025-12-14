import SwiftUI

struct IngredientEngineView: View {
    @ObservedObject var recipeStore: RecipeStore          // レシピメタ用（必要なら）
    @ObservedObject var engineStore: IngredientEngineStore // rows用（本体）
    let recipeId: UUID
    @Binding var path: [Route]


    var body: some View {
        ZStack(alignment: .topLeading) {

            // ✅ “紙面” 本体（スクロール）
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {

                    // タイトル（今は仮）
                    Text("Ingredient Engine")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 4)

                    Text("（Day2は動線優先。エンジン本体はここに実装していく）")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // ✅ ここからが “single のみ”
                    let indexedRows = Array(engineStore.rows.enumerated())
                    ForEach(indexedRows, id: \.element.id) { index, row in
                        rowView(row, index: index)
                    }

                    Spacer(minLength: 120) // 右レールの下端付近でも最後の行が触れる余白
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                
                
                .onAppear { engineStore.seedIfNeeded() }

            }

        }
        .navigationBarBackButtonHidden(true)
        .padding(0) // ← “紙面”を削らない。余白はScroll内で管理
        .overlay {
            RightRailControls(
                mode: .back,
                onPrimary: { if !path.isEmpty { path.removeLast() } },
                onHome: { path = [] },
                onSwipeLeft: { },
                onSwipeRight: { if !path.isEmpty { path.removeLast() } }
            )
        }
        .navigationTitle("Ingredients")
    }

    //✅ここはボディの外
    
    @ViewBuilder
    private func rowView(_ row: IngredientRow, index: Int) -> some View {
        switch row {

        case .single(let item):
            HStack(spacing: 10) {
                Text(item.name.isEmpty ? " " : item.name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.amount)
                    .frame(width: 64, alignment: .trailing)

                Text(item.unit)
                    .frame(width: 42, alignment: .leading)
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 48)         // ✅ 行ごとの高さ
            .padding(.vertical, 6)        // ✅ 行間
            .contentShape(Rectangle())    // ✅ 行全体当たり判定

        case .blockHeader:
            EmptyView()

        case .blockItem:
            EmptyView()
        }
    }

    
    
    //構造体の先端
}
