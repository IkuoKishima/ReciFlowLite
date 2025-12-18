import SwiftUI

struct IngredientEngineView: View {
    let DEBUG = true ////🟡エクステンションでデバッグ背景を有効にする
    @ObservedObject var engineStore: IngredientEngineStore // rows用（本体）
    @ObservedObject var recipeStore: RecipeStore          // レシピメタ用（必要なら）
    //ルーター配置
    @State private var isDeleteMode = false // 削除モード
    // 並替モード配置
    @State private var selectedIndex: Int? = nil


    let recipeId: UUID
    @Binding var path: [Route]






    // MARK: - 行の高さ・行間まとめ
    private let amountWidth: CGFloat = 64 //分量フィールド幅
    private let unitWidth: CGFloat = 42 //単位フィールド幅
    private let rowHeight: CGFloat = 36 //文字の高さ
    private let rowVPadding: CGFloat = 0 //⚠️文字内余白
    



    //───── ブラケット判定（Lite） ─────//
    private enum BracketRole {
        case none
        case top
        case middle
        case bottom
    }

    private func bracketRoleForRow(at index: Int) -> BracketRole {
        guard engineStore.rows.indices.contains(index) else { return .none }

        // blockItem 以外はブラケット対象外（Liteはここをシンプルに）
        guard case .blockItem(let item) = engineStore.rows[index],
              let blockId = item.parentBlockId else {
            return .none
        }

        let prevIsSameBlock: Bool = {
            let prev = index - 1
            guard prev >= 0,
                  engineStore.rows.indices.contains(prev),
                  case .blockItem(let prevItem) = engineStore.rows[prev] else { return false }
            return prevItem.parentBlockId == blockId
        }()

        let nextIsSameBlock: Bool = {
            let next = index + 1
            guard engineStore.rows.indices.contains(next),
                  case .blockItem(let nextItem) = engineStore.rows[next] else { return false }
            return nextItem.parentBlockId == blockId
        }()

        switch (prevIsSameBlock, nextIsSameBlock) {
        case (false, false): return .top
        case (false, true):  return .top
        case (true, true):   return .middle
        case (true, false):  return .bottom
        }
    }
    
    //───── ブラケット部品はここに ─────//
    private let blockIndent: CGFloat = 8
    private let bracketWidth: CGFloat = 12

    @ViewBuilder
    private func bracketColumnLite(at index: Int) -> some View {
        let role = bracketRoleForRow(at: index)

        switch role {
        case .none:
            Rectangle()
                .opacity(0)
                .frame(width: bracketWidth)

        case .top:
            VStack(spacing: 0) {
                Rectangle().opacity(0).frame(height: 6)
                Rectangle().frame(width: 1)
                Spacer()
            }
            .frame(width: bracketWidth)

        case .middle:
            Rectangle()
                .frame(width: 1)
                .frame(maxHeight: .infinity)
                .frame(width: bracketWidth)

        case .bottom:
            VStack(spacing: 0) {
                Spacer()
                Rectangle().frame(width: 1)
                Rectangle().opacity(0).frame(height: 6)
            }
            .frame(width: bracketWidth)
        }
    }

    
    
  
    
    
    // MARK: - デバッグ通知を一箇所にまとめ、ビルドに入らない#️⃣で扱う
    private func debugRowTap(_ row: IngredientRow) {
        #if DEBUG
        print("[DEBUG][RowTap]", row.role)
        #endif
    }
    
    // MARK: - Binding生成ヘルパー関数追加
    
    // ✅ rows の中から「指定 itemId のフィールド」を直接読み書きする Binding を作る
    private func bindingForItemField(
        itemId: UUID,
        get: @escaping (IngredientItem) -> String,
        set: @escaping (inout IngredientItem, String) -> Void
    ) -> Binding<String> {
        Binding(
            get: {
                guard let idx = engineStore.rows.firstIndex(where: { row in
                    switch row {
                    case .single(let it): return it.id == itemId
                    case .blockItem(let it): return it.id == itemId
                    default: return false
                    }
                }) else { return "" }

                switch engineStore.rows[idx] {
                case .single(let it): return get(it)
                case .blockItem(let it): return get(it)
                default: return ""
                }
            },
            set: { newValue in
                guard let idx = engineStore.rows.firstIndex(where: { row in
                    switch row {
                    case .single(let it): return it.id == itemId
                    case .blockItem(let it): return it.id == itemId
                    default: return false
                    }
                }) else { return }

                switch engineStore.rows[idx] {
                case .single(var it):
                    set(&it, newValue)
                    engineStore.rows[idx] = .single(it)

                case .blockItem(var it):
                    set(&it, newValue)
                    engineStore.rows[idx] = .blockItem(it)

                default:
                    break
                }
            }
        )
    }


// MARK: - ページ本体
    
    var body: some View {
        ZStack(alignment: .topLeading) {

            
            // ✅ “紙面” 本体（スクロール）
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {//⚠️行間

                    // ✅ ここからが “single 、EngineStoreを参照して表示するから、engineStore.rows)
                    let indexedRows = Array(engineStore.rows.enumerated())

                    ForEach(indexedRows, id: \.element.id) { index, row in
                        rowWithControls(for: row, at: index)
                    }


                    .animation(.snappy, value: isDeleteMode)


                    Spacer(minLength: 120) // 右レールの下端付近でも最後の行が触れる余白
                }
                .padding(.horizontal, 8) //⚠️大外余白
                .padding(.top, 2) //⚠️タイトル以下余白
                .padding(.trailing, 4) // ⚠️右干渉回避
                .debugBG(DEBUG, Color.orange.opacity(0.06), "STACK")
                
                .onAppear {
                    engineStore.loadIfNeeded() // 画面に入ったら読み込み
                }
                
                .onDisappear {
                    engineStore.saveNow() // 画面から出たら保存・ログはEngineStoreに配置する
                #if DEBUG
                    print("✅ saved & cleared \(engineStore.rows.count) rows")
                #endif
                }



            }
            .debugBG(DEBUG, Color.purple.opacity(0.05), "SCROLL")

        }
        .navigationBarBackButtonHidden(true)
        .padding(0) // ← “紙面”を削らない。余白はScroll内で管理
        
        // MARK: - 初期化された右ドックボタン順に配置・ここでアイテム追加削除の指示をする
        
        //⚠️ここで仮ドックボタンを呼んでいるが、順序はRightRailControlsで書いた順
        .overlay {
            RightRailControls(
                mode: .back,
                showsDelete: true,
                isDeleteMode: isDeleteMode,
                onToggleDelete: { isDeleteMode.toggle() },
                
                //🟡
                onAddSingle: {
                    let inserted = engineStore.addSingle(after: selectedIndex)
                    selectedIndex = inserted
                },
                
                
                onAddBlock: {
                    let inserted = engineStore.addBlock(after: selectedIndex) // ✅ header only版
                    selectedIndex = inserted
                },
                
                
                // ✅ ひとまず onPrimary を「＋」に割り当て（最短で追加が動く）
                onPrimary: { if !path.isEmpty { path.removeLast() } },

                onHome: { path = [] },
                onSwipeLeft: { },
                onSwipeRight: { if !path.isEmpty { path.removeLast() } }
            )
        }
        .navigationTitle("Ingredients")
    }

    //✅ここはボディの外
   
 
    
    // MARK: -　IngredientEngine_v15 型構造の導入
    
    
    // MARK: - 📝🌟　削除・並び替えをする　「デザインではなく構造」　🌟📝
        
    @ViewBuilder
    private func controlColumn(for row: IngredientRow, at index: Int) -> some View {
        Image(systemName: "minus.circle.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(.red)
            .opacity(isDeleteMode ? 1 : 0)
            .frame(width: 20)
            .contentShape(Rectangle())
            .allowsHitTesting(isDeleteMode)
            .onTapGesture {
                guard isDeleteMode else { return }
                switch row {
                case .single(let item), .blockItem(let item):
                    engineStore.deleteRow(itemId: item.id)
                case .blockHeader(let block):
                    engineStore.deleteBlock(blockId: block.id)
                }
            }
            .debugBG(DEBUG, .red.opacity(0.12), "DEL")
    }
    
    
    
    //───── rowView を「中身だけ」） ─────//
    @ViewBuilder
    private func rowView(for row: IngredientRow, at index: Int) -> some View {
        contentForRow(row, at: index)
        
    }
    

    //───── 削除と並び替えをひとかたまりに ─────//　ForEachでこれを呼ぶ
    
    @ViewBuilder
    private func rowWithControls(for row: IngredientRow, at index: Int) -> some View {
        HStack(spacing: 6) {
            controlColumn(for: row, at: index)
            rowView(for: row, at: index)
        }
        .frame(minHeight: rowHeight) //✅ 高さはここで統一
        .contentShape(Rectangle())
    }

    
    //ここで表示するレコードの処理を配置する
    //───── 行としての本体 ───── ✅冒頭定数設定で、amount/unit領域の調整は一元化
    @ViewBuilder //これらは、弁当箱屋さんのように入れ物専門で作る機能、どこに何が幾つはいるかを生成している
    private func contentForRow(_ row: IngredientRow, at index: Int) -> some View {
            switch row {
                
            case .single(let item):
                HStack(spacing: 8) { //⚠️🍽️内側寄せ
                    TextField("材料", text: bindingForItemField(
                        itemId: item.id,
                        get: { $0.name },
                        set: { $0.name = $1 }
                    ))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    TextField("分量", text: bindingForItemField(
                        itemId: item.id,
                        get: { $0.amount },
                        set: { $0.amount = $1 }
                    ))
                    .frame(width: amountWidth, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                    
                    TextField("単位", text: bindingForItemField(
                        itemId: item.id,
                        get: { $0.unit },
                        set: { $0.unit = $1 }
                    ))
                    .frame(width: unitWidth, alignment: .leading)
                }

                
            case .blockHeader(let block):
                HStack(spacing: 4) {

                    // 🔹 block インデント（singleとの差）
                    Spacer()
                        .frame(width: blockIndent)

                    // 🔹 ブラケット列（Liteではダミー）
                    bracketColumnLite(at: index)
                        .debugBG(DEBUG, .pink.opacity(0.12), "BR")

                    // 🔹 Header 本体
                    IngredientBlockHeaderRowView(
                        store: engineStore,
                        block: block
                    ) { inserted in
                        selectedIndex = inserted
                    }
                }

                
            case .blockItem(let item):
                HStack(spacing: 4) {

                    // ブロックインデント（構造）
                    Spacer()
                        .frame(width: blockIndent)

                    // ブラケット列（🟡将来差し替え🟡）
                    bracketColumnLite(at: index)
                        .debugBG(DEBUG, .pink.opacity(0.12), "BR")

                    // 中身
                    HStack(spacing: 8) {
                        TextField("材料", text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.name },
                            set: { $0.name = $1 }
                        ))
                        .frame(maxWidth: .infinity, alignment: .leading)

                        TextField("分量", text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.amount },
                            set: { $0.amount = $1 }
                        ))
                        .frame(width: amountWidth, alignment: .trailing)
                        .multilineTextAlignment(.trailing)

                        TextField("単位", text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.unit },
                            set: { $0.unit = $1 }
                        ))
                        .frame(width: unitWidth, alignment: .leading)
                    }
                }
            }
    }
    
    
    
    


    
    //構造体の先端
    
}

// MARK: - プレビューを出す時、RecipeStoreの依存を満たすためだけの存在
#if DEBUG
extension RecipeStore {
    static func previewStore() -> RecipeStore {
        RecipeStore()
    }
}
#endif

#if DEBUG
// MARK: - Preview Wrapper
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
            .navigationTitle("Ingredients")
    }
}
#endif


// MARK: - 削除APIの追記・利用はViewに@Stateで状態追記する事で読み込まれる

extension IngredientEngineStore {

    func deleteBlock(blockId: UUID) {
        rows.removeAll { row in
            switch row {
            case .blockHeader(let b):
                return b.id == blockId
            case .blockItem(let item):
                return item.parentBlockId == blockId
            default:
                return false
            }
        }
    }



    func deleteRow(itemId: UUID) {
        rows.removeAll { row in
            switch row {
            case .single(let item), .blockItem(let item):
                return item.id == itemId
            default:
                return false
            }
        }
    }
}






// MARK: - 行の役割を明文化（今後の追加機能がrole基準で書ける）
// ✅当たり判定・右レールドック干渉調整・編集時操作可不可分岐・ブラケット判定入り口全てで扱いやすくする

enum RowRole {
    case single
    case blockHeader
    case blockItem
}
extension IngredientRow {
    var role: RowRole {
        switch self {
        case .single:      return .single
        case .blockHeader: return .blockHeader
        case .blockItem:   return .blockItem
        }
    }
}

// MARK: - 🟡ビュー担当を可視化するためのデバッグ背景ヘルパー
extension View {
    @ViewBuilder
    func debugBG(_ enabled: Bool, _ color: Color, _ label: String = "") -> some View {
        if enabled {
            self.background(color)
                .overlay(alignment: .topLeading) {
                    if !label.isEmpty {
                        Text(label)
                            .font(.caption2)
                            .padding(4) //⚠️これ何？？
                            .background(.black.opacity(0.2))
                            .foregroundStyle(.white)
                    }
                }
        } else {
            self
        }
    }
}

// MARK: - Preview専用 Store（⚠️ Xcodeクラッシュ対策で実データ禁止）
extension IngredientEngineStore {
    
    

    static func previewStore() -> IngredientEngineStore {
        let store = IngredientEngineStore(parentRecipeId: UUID())

        // --- single ---
        store.rows = [
            .single(.init(
                parentRecipeId: store.parentRecipeId,
                name: "酒",
                amount: "30",
                unit: "ml"
            )),
            .single(.init(
                parentRecipeId: store.parentRecipeId,
                name: "醤油",
                amount: "15",
                unit: "ml"
            )),
        ]

        // --- block ---
        let block = IngredientBlock(
            parentRecipeId: store.parentRecipeId,
            orderIndex: 2,
            title: "合わせ調味料"
        )

        store.rows.append(.blockHeader(block))

        store.rows.append(
            .blockItem(.init(
                parentRecipeId: store.parentRecipeId,
                parentBlockId: block.id,
                name: "砂糖",
                amount: "10",
                unit: "g"
            ))
        )

        store.rows.append(
            .blockItem(.init(
                parentRecipeId: store.parentRecipeId,
                parentBlockId: block.id,
                name: "塩",
                amount: "1",
                unit: "tsp"
            ))
        )

        // --- empty single（追加用の空行想定）---
        store.rows.append(
            .single(.init(parentRecipeId: store.parentRecipeId))
        )

        return store
    }
}
