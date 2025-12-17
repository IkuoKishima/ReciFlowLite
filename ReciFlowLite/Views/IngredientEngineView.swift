import SwiftUI

struct IngredientEngineView: View {
    @ObservedObject var recipeStore: RecipeStore          // レシピメタ用（必要なら）
    @ObservedObject var engineStore: IngredientEngineStore // rows用（本体）
    let recipeId: UUID
    @Binding var path: [Route]
    
    @State private var isDeleteMode = false
    @State private var selectedIndex: Int? = nil


    
    // MARK: - 書式定数の設置
    
    private let amountWidth: CGFloat = 64
    private let unitWidth: CGFloat = 42
    private let leftGutterWidth: CGFloat = 18   // ← 仮。将来ここが「つまみ/ブラケット列」になる
    private let rowHeight: CGFloat = 36
    private let rowVPadding: CGFloat = 2
    
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
                LazyVStack(alignment: .leading, spacing: 8) {

                    // タイトル（今は仮）
                    Text("Ingredient Engine")
                        .font(.title2.weight(.semibold))
                        .padding(.top, 4)

                    Text("（Day2は動線優先。エンジン本体はここに実装していく）")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // ✅ ここからが “single 、EngineStoreを参照して表示するから、engineStore.rows)
                    let indexedRows = Array(engineStore.rows.enumerated())

                    ForEach(indexedRows, id: \.element.id) { index, row in
                        rowView(for: row)
                            .contentShape(Rectangle())   // 行全体タップを安定させる
                            .onTapGesture {
                                debugRowTap(row)

                                if isDeleteMode {
                                    switch row {
                                    case .single(let item), .blockItem(let item):
                                        engineStore.deleteRow(itemId: item.id)
                                    case .blockHeader(let block):
                                        engineStore.deleteBlock(blockId: block.id)
                                    }
                                } else {
                                    // ✅ ここが今回の目的：追加の基準行を記録
                                    selectedIndex = index
                                    #if DEBUG
                                    print("🎯 selectedIndex=\(index) role=\(row.role)")
                                    #endif
                                }
                            }
                    }

                    
                    

                    Spacer(minLength: 120) // 右レールの下端付近でも最後の行が触れる余白
                }
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .onAppear {
                    engineStore.loadIfNeeded() // 画面に入ったら読み込み
                }
                
                .onDisappear {
                    engineStore.saveNow() // 画面から出たら保存・ログはEngineStoreに配置する
//                    engineStore.rows.removeAll() // これで次回はDBから読む
                #if DEBUG
                    print("✅ saved & cleared \(engineStore.rows.count) rows")
                #endif
                }



            }

        }
        .navigationBarBackButtonHidden(true)
        .padding(0) // ← “紙面”を削らない。余白はScroll内で管理
        
        //⚠️ここで仮ドックボタンを呼んでいるが、順序はRightRailControlsで書いた順
        .overlay {
            RightRailControls(
                mode: .back,
                showsDelete: true,
                isDeleteMode: isDeleteMode,
                onToggleDelete: { isDeleteMode.toggle() },
                onAddSingle: {
                    let inserted = engineStore.addSingle(after: selectedIndex)
                    selectedIndex = inserted
                },
                onAddBlock: {
                    let inserted = engineStore.addBlock(after: selectedIndex) // ✅ header only版
                    selectedIndex = inserted
                },
                // ✅ ひとまず onPrimary を「＋」に割り当て（最短で追加が動く）
                onPrimary: {
                    let inserted = engineStore.addSingle(after: selectedIndex)
                    selectedIndex = inserted
                        },
                onHome: { path = [] },
                onSwipeLeft: { },
                onSwipeRight: { if !path.isEmpty { path.removeLast() } }
            )
        }
        .navigationTitle("Ingredients")
    }

    //✅ここはボディの外
    // MARK: - 書式設定、以下のcontentForRowを「乗せる」事で責務分担、視認性の向上に伴い、後のコードが巨大化に備える

    //🎯.allowsHitTestingの処理を見やすくするためここに設置（削除モードの時だけ触れる）
    private func isRowHittable(_ row: IngredientRow) -> Bool {
        if isDeleteMode { return true }
        return row.role != .blockHeader
    }
    
    //───── 行としての共通書式設定(装飾スキン） ─────//
    @ViewBuilder
    private func rowView(for row: IngredientRow) -> some View {

        Group {
            HStack(spacing: 0) {

                // ✅ 左ガター（余白）将来の縦摘み列の予約席
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
        //🎯当たり制御＋当たり判定（削除モードの時だけ触れる）
        .allowsHitTesting(isRowHittable(row))
        
        .onTapGesture {
            debugRowTap(row)

            guard isDeleteMode else { return }

            switch row {
            case .single(let item),
                 .blockItem(let item):
                engineStore.deleteRow(itemId: item.id)

            case .blockHeader(let block):
                engineStore.deleteBlock(blockId: block.id)
            }
        }

    }

    
    
    //ここで表示するレコードの処理を配置する
    //───── 行としての本体 ───── ✅冒頭定数設定で、amount/unit領域の調整は一元化
    @ViewBuilder //これらは、弁当箱屋さんのように入れ物専門で作る機能、どこに何が幾つはいるかを生成している
    private func contentForRow(_ row: IngredientRow) -> some View {
            switch row {
                
            case .single(let item):
                HStack(spacing: 6) {
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
                HStack(spacing: 0) {
                    IngredientBlockHeaderRowView(store: engineStore, block: block)
                }
                
            case .blockItem(let item):
                HStack(spacing: 4) {
                    
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
                .padding(.leading, 12) // ← ブロック内感だけ付ける（仮）
            }
    }
    
    //構造体の先端
}
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
