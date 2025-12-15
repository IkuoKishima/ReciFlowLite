import SwiftUI

struct IngredientEngineView: View {
    @ObservedObject var recipeStore: RecipeStore          // レシピメタ用（必要なら）
    @ObservedObject var engineStore: IngredientEngineStore // rows用（本体）
    let recipeId: UUID
    @Binding var path: [Route]
    
    // MARK: - 書式定数の設置
    private let leftGutterWidth: CGFloat = 18   // ← 仮。将来ここが「つまみ/ブラケット列」になる
    private let rowHeight: CGFloat = 36
    private let rowVPadding: CGFloat = 2

    


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
                        rowView(for: row)
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
    // MARK: - ここで書式設定を取りまとめ、以下のcontentForRowを「乗せる」事で責務分担、視認性の向上に伴い、後のコードが巨大化に備える
    //───── 行としての共通書式設定 ─────
    @ViewBuilder
    private func rowView(for row: IngredientRow) -> some View {

        Group {
            HStack(spacing: 0) {

                // ✅ 左ガター（将来の縦摘み列の予約席）
                Color.clear
                    .frame(width: leftGutterWidth)

                // ✅ ここから中身（single / header / item）
                contentForRow(row)
            }
        }
        .font(.body)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: rowHeight)
        .padding(.vertical, rowVPadding)
        .contentShape(Rectangle())
    }

    
    
    //ここで表示するレコードの処理を配置する
    //───── 行としての本体 ─────
    @ViewBuilder
    private func contentForRow(_ row: IngredientRow) -> some View {
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
    

    
    
    //構造体の先端
}
