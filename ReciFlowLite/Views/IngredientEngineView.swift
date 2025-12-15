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
                
                
                .onAppear { engineStore.seedIfNeeded() } //✅ScrollViewの LazyVStack の外側、ZStackに配置、一度だけEngineStoreデータを呼ぶ）

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
        Group {
            switch row {
                
            case .single(let item):
                HStack(spacing: 6) {
                    
                    Text(item.name.isEmpty ? " " : item.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    Text(item.amount)
                        .frame(width: 64, alignment: .trailing)
                    
                    
                    Text(item.unit)
                        .frame(width: 42, alignment: .leading)
                }

                
            case .blockHeader(let block):
                HStack(spacing: 0) {
                    IngredientBlockHeaderRowView(title: block.title.isEmpty ? "合わせ調味料" : block.title)
                }
                
            case .blockItem(let item):
                HStack(spacing: 4) {
                    
                    Text(item.name.isEmpty ? " " : item.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    
                    Text(item.amount)
                        .frame(width: 64, alignment: .trailing)
                    
                    
                    Text(item.unit)
                        .frame(width: 42, alignment: .leading)
                }
                .padding(.leading, 12) // ← ブロック内感だけ付ける（仮）
            }
        }
        //✅左に余白の最低保証を入れる時、全体をGroupで包んで、それに対してパディングをかける。ビューそのものにパディングはつけられない
        //✅内部にいくつも書式を書かなくても、グループ内書式として共通化ができる
        // ───── 行としての共通書式設定 ───── //Groupで囲った範囲内に適用されるため、コードを減らせて✅「可読性の向上」となる
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 36)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .padding(.leading, 6)   // ← 左の最低保証（将来カラム用）
    }
    

    
    
    //構造体の先端
}
