/// MARK: - IngredientEngineView.swift

import SwiftUI

struct IngredientEngineView: View {
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    let DEBUG = true ////🟡エクステンションでデバッグ背景を有効にする
    #else
    let DEBUG = false
    #endif
    
    let recipeTitle: String
    @ObservedObject var recipeStore: RecipeStore
    @ObservedObject var store: IngredientEngineStore
    @State private var isDeleteMode = false // 削除モード
    @State private var selectedRowId: UUID? = nil
    
    private enum Field { case name, amount, unit }
    @StateObject private var router = FocusRouter()
    @State private var didRequestInitialFocus = false



    
    // 外から注入される“アプリ操作”
    var onPrimary: () -> Void = {}
    var onHome: () -> Void = {}
    var onSwipeLeft: () -> Void = {}
    var onSwipeRight: () -> Void = {}
    var onDelete: () -> Void = {}   // 左の削除領域用（必要なら）

    // MARK: - キーボード閉じ関数（確実版）
    private func dismissKeyboard() {
    #if canImport(UIKit)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?
            .endEditing(true)
    #endif
    }



    // MARK: - ──── 行の高さ・行間はここの集約　 ─────　//
    
    private let amountWidth: CGFloat = 42 //分量フィールド幅
    private let unitWidth: CGFloat = 66 //単位フィールド幅
    private let leftGutterWidth: CGFloat = 20 //左ガターの幅
   
    private let rightRailWidth: CGFloat = 20 // ⚠️右干渉回避 44
    private let rightRailGap: CGFloat = 8  // ちょい余白（好み）

    private let rowHeightSingle: CGFloat      = 34  // 単体＆blockItem
    private let rowHeightBlockHeader: CGFloat = 34 //見出しだけ少し高く
    
    // ブロックアイテム行の高さを補正
    private func rowHeight(for row: IngredientRow) -> CGFloat {
        switch row {
        case .blockHeader: return rowHeightBlockHeader
        default:           return rowHeightSingle
        }
    }

    
    // MARK: - ────　縦横アクセサリ部品はここの集約　 ─────　//
    private enum EngineCommand {
        case dismissKeyboard
        case moveUp
        case moveDown
        case moveLeft
        case moveRight
        case enterNext          // Return/Enter
        case addSingle
        case addBlock
    }

    private func perform(_ cmd: EngineCommand) {
        switch cmd {
        case .dismissKeyboard:
            dismissKeyboard()

        case .moveUp:
            router.moveUp()

        case .moveDown:
            router.moveDown()

        case .moveLeft:
            router.moveLeft()

        case .moveRight:
            router.moveRight()

        case .enterNext:
            router.enterNext()

        case .addSingle:
            let inserted = store.addSingle(after: store.indexOfRow(id: router.current?.rowId))
            router.rebuild(rows: store.rows)
            if case .single(let it) = store.rows[inserted] {
                router.set(.init(rowId: it.id, field: .name))
            }

        case .addBlock:
            _ = store.addBlock(after: store.indexOfRow(id: router.current?.rowId))
            router.rebuild(rows: store.rows)
        }
    }


    private func focusableRowIdForTap(row: IngredientRow, index: Int) -> UUID? {
        switch row {
        case .single(let it):
            return it.id

        case .blockItem(let it):
            return it.id

        case .blockHeader(let block):
            var i = index + 1
            while i < store.rows.count {
                switch store.rows[i] {
                case .blockItem(let it) where it.parentBlockId == block.id:
                    return it.id
                case .blockItem:
                    // 別ブロックのitem（通常ここには来ない想定だが念のため）
                    return nil
                case .blockHeader:
                    // 次のブロックに入った＝このブロックには item が無い
                    return nil
                case .single:
                    // ブロックが途切れた
                    return nil
                }
                i += 1
            }
            return nil
        }
    }




    
    // MARK: - ────　ブラケット部品はここの集約　 ─────　//
   
    private let blockIndent: CGFloat = 8
    private let bracketWidth: CGFloat = 12 //bracketWidth は正値、食い込みは offset が地雷を作らない鍵
// 2️⃣左から2番目の列、ブロック行のブラケット位置
    private enum BracketRole {
        case none
        case top
        case middle
        case bottom
    }


    // この index の行がブロック中ならブラケット位置を返す
    
    private func bracketRoleForRow(at index: Int) -> BracketRole {
        guard store.rows.indices.contains(index) else { return .none }
        
        // v5 では「カッコ対象」はブロック内アイテム (.blockItem) だけ
        guard case .blockItem(let item) = store.rows[index],
              let blockId = item.parentBlockId else {
            return .none
        }
        
        // 直前が同じ blockId の .blockItem か？
        let prevIsSameBlock: Bool = {
            let prev = index - 1
            guard prev >= 0,
                  store.rows.indices.contains(prev),
                  case .blockItem(let prevItem) = store.rows[prev]
            else { return false }
            return prevItem.parentBlockId == blockId
        }()
        
        // 直後が同じ blockId の .blockItem か？
        let nextIsSameBlock: Bool = {
            let next = index + 1
            guard store.rows.indices.contains(next),
                  case .blockItem(let nextItem) = store.rows[next]
            else { return false }
            return nextItem.parentBlockId == blockId
        }()
        
        switch (prevIsSameBlock, nextIsSameBlock) {
        case (false, false):
            // 1 行だけのブロック → ひとまず top 扱い（必要なら後で専用ロール追加でもOK）
            return .top
        case (false, true):
            return .top
        case (true, true):
            return .middle
        case (true, false):
            return .bottom
        }
    }
    
    // ブロックアイテムとのブラケット距離はオフセットマイナスで決める
    @ViewBuilder
    private func bracketColumn(at index: Int) -> some View {
    let role = bracketRoleForRow(at: index)

    Group {
        switch role {
        case .none:
            Rectangle()
                .opacity(0)
                .frame(width: 12)
                
        case .top:
            BracketPartView(
                type: .top,
                style: .rounded,
                lineStyle: .solid,
                color: .purple,
                lineWidth: 1,
                addLength: 12,
                extraHorizontalLength: -12
            )
            .frame(width: 12)
            .offset(x: -2, y: 12)

        case .middle:
            BracketPartView(
                type: .line,
                lineStyle: .solid,
                color: .purple,
                lineWidth: 1,
                addLength: 26,

            )
            .frame(width: 12, alignment: .leading)
            .offset(x: -2)

        case .bottom:
            BracketPartView(
                type: .bottom,
                style: .rounded,
                lineStyle: .solid,
                color: .purple,
                lineWidth: 1,
                addLength: 12,
                extraHorizontalLength: -12
            )
            .frame(width: 12)
            .offset(x: -2, y: -12)
         }
     }
 }
  
    
    // MARK: - Binding生成ヘルパー関数追加
    
    // ✅ rows の中から「指定 itemId のフィールド」を直接読み書きする Binding を作る
    private func bindingForItemField(
        itemId: UUID,
        get: @escaping (IngredientItem) -> String,
        set: @escaping (inout IngredientItem, String) -> Void
    ) -> Binding<String> {

        // ① itemId から rows の index を引く処理を共通化
        func indexForItem(_ itemId: UUID) -> Int? {
            store.rows.firstIndex { row in
                switch row {
                case .single(let it):    return it.id == itemId
                case .blockItem(let it): return it.id == itemId
                default:                return false
                }
            }
        }

        return Binding(
            get: {
                guard let idx = indexForItem(itemId) else { return "" }
                switch store.rows[idx] {
                case .single(let it):    return get(it)
                case .blockItem(let it): return get(it)
                default:                return ""
                }
            },
            set: { newValue in
                guard let idx = indexForItem(itemId) else { return }

                var didUpdate = false

                switch store.rows[idx] {
                case .single(var it):
                    let old = get(it)
                    guard old != newValue else { return }     // ✅ 同値なら何もしない
                    set(&it, newValue)
                    store.rows[idx] = .single(it)
                    didUpdate = true

                case .blockItem(var it):
                    let old = get(it)
                    guard old != newValue else { return }     // ✅ 同値なら何もしない
                    set(&it, newValue)
                    store.rows[idx] = .blockItem(it)
                    didUpdate = true

                default:
                    break
                }

                // ✅ 保存予約は「最後に1回だけ」
                if didUpdate {
                    store.markDirtyAndScheduleSave(reason: "text edit")
                }
            }
        )
    }



    // MARK: - ===== 🟨　表示ページ本体はここから　🟨　=====　//
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // ===== スクロール本体 =====
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {//⚠️罫線も伸ばす
                        
                        
                        //EngineStoreを参照して表示するから、engineStore.rows)
                        let indexedRows = Array(store.rows.enumerated())
                        
                        ForEach(indexedRows, id: \.element.id) { index, row in
                            rowWithControls(for: row, at: index)
                                .id(row.id) // ← row.rowId ではなく「その行の本体ID」に統一
                                .padding(.horizontal, 8) //⚠️画面端からの距離
                                .frame(height: rowHeight(for: row))//ヘッダ高連携
                            //                        .debugBG(DEBUG, .orange.opacity(0.06), "行間")
                        }
                        
                        
                        
                        
                        .animation(.snappy, value: isDeleteMode)
                        Spacer(minLength: 120) // 右レールの下端付近でも最後の行が触れる余白
                    }
                    
                    .padding(.trailing, rightRailWidth + rightRailGap)
                    //                .debugBG(DEBUG, Color.orange.opacity(0.16), "STACK")
                    
                    // ビューが現れた瞬間を監視するトリガー
                    .onAppear {
                        store.loadIfNeeded()
                        router.rebuild(rows: store.rows)
                    }

                    .onChange(of: store.rowsRevision) { _ in
                        router.rebuild(rows: store.rows)
                    }

                    
                    // フォーカスの実態を監視しRouter → ScrollView の橋渡し
                    .onChange(of: router.current) { newValue in
                        guard let c = newValue else { return }
                        //rowId が今の rows に存在するときだけ scroll
                        guard store.indexOfRow(id: c.rowId) != nil else { return }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(c.rowId, anchor: .center)
                            }
                        }
                    }
                    
                    // アプリライフサイクルを監視し落ちる前に絶対保存するトリガー
                    .onChange(of: scenePhase) { phase in
                        if phase == .background {
                            let didSave = store.saveNow(force: true)
                            if didSave {
                                recipeStore.touchRecipeUpdatedAt(store.parentRecipeId)
                            }
                        }
                    }
                    // ビューが消える瞬間を監視するトリガー
                    .onDisappear {
                        dismissKeyboard()
                        router.clear()

                        let didSave = store.saveNow(force: true)
                        if didSave {
                            recipeStore.touchRecipeUpdatedAt(store.parentRecipeId)
                        }
                    }



                }
                //            .debugBG(DEBUG, Color.purple.opacity(0.08), "body")
            }
        }
        
        // MARK: - ──── 右ドックボタン 追加・削除・移動・ホーム ──── //
        .overlay(alignment: .topTrailing) {
            // ① 土台：右が濃く、左へ霞む（帯幅を制御）
                    LinearGradient(
                        colors: [
                            Color.brown.opacity(0.28), // 紙の濃い端
                            Color.brown.opacity(0.18),
                            Color.brown.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .trailing,
                        endPoint: .leading
                    )
                    .frame(width: 40 + 4) // 44=当たり判定 + 霞み
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                    // ② 縁のハイライト（ガラスの“角”）
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1)
                        .offset(x: -2)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    // ③ 反射線（細い光。あると急にガラスになる）
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: 10)      // 反射線の太さ
                    .offset(x: -10)        // 右端から少し内側
                    .blendMode(.screen)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

            
            
            
            
            UIKitRightDock(
                mode: .back,
                showsDelete: true,
                showsAdd: true,
                showsKeyboardDismiss: true,
                isDeleteMode: isDeleteMode,

                onToggleDelete: {
                    // ここは今まで通りでOK（ただし “閉じる→切替” の順を統一すると安定）
                    dismissKeyboard()
                    isDeleteMode.toggle()
                },

                onAddSingle: { perform(.addSingle) },

                onAddBlock:  { perform(.addBlock) },


                onPrimary: {
                    // UIKit側で閉じるボタンもあるが、遷移前にも閉じると事故が減る
                    dismissKeyboard()
                    router.clear()
                    // “キーボード収納の開始” を先に走らせてから遷移
                    DispatchQueue.main.async {
                        onPrimary()
                    }
                },
                onHome: {
                    dismissKeyboard()
                    onHome()
                },

                onSwipeLeft: {
                    dismissKeyboard()
                    onSwipeLeft()
                },
                onSwipeRight: {
                    dismissKeyboard()
                    onSwipeRight()
                },
                centerYRatio: 0.28, minBottomPadding: 0
            )
            // 右端に“常駐する領域”を確保
            .frame(width: 44)//⚠️背面干渉回避
            .ignoresSafeArea(.keyboard, edges: .bottom)//SafeArea管理
        }
        
        
//                    .debugBG(DEBUG, Color.green.opacity(0.25), "干渉領域")
        .navigationBarBackButtonHidden(true)
        .padding(0) // “紙面”を削らない。余白はScroll内で管理
        .navigationTitle(recipeTitle.isEmpty ? "材料" : recipeTitle)

        

    }
    //✅ここはボディの外
   
    
    
    // MARK: - ──── 📝🌟　削除・並び替えをする　「デザインではなく構造」　🌟📝 ──── //
        

    @ViewBuilder
    private func controlColumn(for row: IngredientRow, at index: Int) -> some View {
        ZStack {
            Image(systemName: "minus.circle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.red)
                .opacity(isDeleteMode ? 1 : 0)
        }
        .frame(width: leftGutterWidth, height: 36, alignment: .center)
        .contentShape(Rectangle())
        .allowsHitTesting(isDeleteMode)
        
        .onTapGesture {
            guard isDeleteMode else {
                selectedRowId = row.id
                store.userDidSelectRow(row.id)
                return
            }

            selectedRowId = row.id
            store.deleteRow(at: index)

            if store.rows.isEmpty {
                selectedRowId = nil
                store.globalRailRowId = nil
            } else {
                let nextIndex = min(index, store.rows.count - 1)
                selectedRowId = store.rows[nextIndex].id
                store.globalRailRowId = store.rows[nextIndex].id
            }

        }
//        .debugBG(DEBUG, .red.opacity(0.12), "削")
    }

    
    // MARK: -  ───── 削除と並び替えをひとかたまりに ───── //　ForEachでこれを呼ぶ
    // ここが唯一の横レイアウトにしています
    @ViewBuilder
    private func rowWithControls(for row: IngredientRow, at index: Int) -> some View {
        HStack(spacing: 8) { //⚠️削除ボタンと文字の距離
            controlColumn(for: row, at: index)//左ガター
            rowView(for: row, at: index)       //本体
        }
        
        
        // 【 下線 】
        .overlay(
            Rectangle()
                .frame(height: 0.5) //線の太さ
                .foregroundColor(Color(.systemGray4).opacity(0.75)) //線の濃さ
                .padding(.leading, leftGutterWidth),
            alignment: .bottom
        )
        .frame(minHeight: rowHeightSingle) //✅ 高さはここで統一
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isDeleteMode else { return }// ✅ 削除中は行タップ無効🆑連打遅延対策
            selectedRowId = row.id
            store.userDidSelectRow(row.id)


            // ✅ block rail 更新（blockHeader / blockItem 両対応）
            if case .blockHeader(let block) = row {
                store.userDidSelectRowInBlock(blockId: block.id, rowId: block.id)
            }
            if case .blockItem(let item) = row, let blockId = item.parentBlockId {
                store.userDidSelectRowInBlock(blockId: blockId, rowId: row.id)
            }
            
            if let rid = focusableRowIdForTap(row: row, index: index) {
                // “次の移動の起点” をタップだけで確定させる（v15踏襲）
                router.reportFocused(rowId: rid, field: .name)
            }



            DBLOG("✅ tapped index=\(index) role=\(row.role) rail=\(row.id)")
  
        }


    }
    //───── rowView を「中身だけ」） ─────//
    @ViewBuilder
    private func rowView(for row: IngredientRow, at index: Int) -> some View {
        contentForRow(row, at: index)
    }
    
    //───── 行としての本体 ───── ✅冒頭定数設定で、amount/unit領域の調整は一元化
    @ViewBuilder //これらは、弁当箱屋さんのように入れ物専門で作る機能、どこに何が幾つはいるかを生成している
    private func contentForRow(_ row: IngredientRow, at index: Int) -> some View {
        
        switch row {
                
            case .single(let item):
                HStack(spacing: 8) { //⚠️内側寄せ
                    SelectAllTextField(
                        text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.name },
                            set: { $0.name = $1 }
                        ),
                        placeholder: "材料",
                        shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .name,
                        config: .init(
                            onDidBecomeFirstResponder: { },
                            onCommit: { perform(.enterNext) },
                            internalFocus: .init(
                                begin: { router.beginInternalFocusUpdate() },
                                end:   { router.endInternalFocusUpdate() }
                            ),
                            focus: .init(
                                rowId: item.id,
                                field: .name,
                                onReport: { id, field in
                                    router.reportFocused(rowId: id, field: field)
                                }
                            ),
                            nav: .init(
                                done:  { perform(.dismissKeyboard) },
                                up:    { perform(.moveUp) },
                                down:  { perform(.moveDown) },
                                left:  { perform(.moveLeft) },
                                right: { perform(.moveRight) }
                            )
                        )
                    )


//                    .debugBG(DEBUG, Color.orange.opacity(0.6), "Single")//✅
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 30)
                    
                    
                    SelectAllTextField(
                        text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.amount },
                            set: { $0.amount = $1 }
                        ),
                        placeholder: "分量",
                        shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .amount,
                        textAlignment: .right,           // ← 差分①
                        keyboardType: .decimalPad,       // ← 差分②
                        config: .init(
                            onCommit: { perform(.enterNext) },
                            internalFocus: .init(
                                begin: { router.beginInternalFocusUpdate() },
                                end:   { router.endInternalFocusUpdate() }
                            ),
                            focus: .init(
                                rowId: item.id,
                                field: .amount,          // ← 差分③
                                onReport: { id, field in
                                    router.reportFocused(rowId: id, field: field)
                                }
                            ),
                            nav: .init(
                                done:  { perform(.dismissKeyboard) },
                                up:    { perform(.moveUp) },
                                down:  { perform(.moveDown) },
                                left:  { perform(.moveLeft) },
                                right: { perform(.moveRight) }
                            )
                        )
                    )

                    .frame(width: amountWidth, alignment: .trailing)



                    SelectAllTextField(
                        text: bindingForItemField(
                            itemId: item.id,
                            get: { $0.unit },
                            set: { $0.unit = $1 }
                    ),
                        placeholder: "単位",
                        shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .unit,
                        config: .init(
                            onDidBecomeFirstResponder: { },
                            onCommit: { perform(.enterNext) },
                            internalFocus: .init(
                                begin: { router.beginInternalFocusUpdate() },
                                end:   { router.endInternalFocusUpdate() }
                            ),
                            focus: .init(
                                rowId: item.id,
                                field: .unit,
                                onReport: { id, field in
                                    router.reportFocused(rowId: id, field: field)
                                }
                            ),
                            nav: .init(
                                done:  { perform(.dismissKeyboard) },
                                up:    { perform(.moveUp) },
                                down:  { perform(.moveDown) },
                                left:  { perform(.moveLeft) },
                                right: { perform(.moveRight) }
                            )
                        )
                    )
                    .frame(width: unitWidth, alignment: .leading)
                }

                
            case .blockHeader(let block):
                HStack(spacing: 0) {
                    // 🔹 block インデント（singleとの差）
                    Spacer()
                        .frame(width: blockIndent)
                    

                    // 🔹 Header 本体
                    IngredientBlockHeaderRowView(
                        store: store,
                        block: block
                    ) { inserted in
                        // inserted は rows の index で返ってくる想定
                        // → 選択は rowId で持つ
                        if store.rows.indices.contains(inserted) {
                            let newId = store.rows[inserted].id
                            selectedRowId = newId
                            store.userDidSelectRow(newId)
                        } else {
                            // 何もしない（前の選択を維持）
                        }
                    }
                }
//                .debugBG(DEBUG, Color.blue.opacity(0.6), "header")//✅

                
                
                
            case .blockItem(let item):
                HStack(spacing: 4) {

                    // ブロックインデント（構造）
                    Spacer().frame(width: blockIndent)
//                        .debugBG(DEBUG, .blue.opacity(0.10), "INDENT")
                    // ブラケット列
                    bracketColumn(at: index)
//                        .debugBG(DEBUG, .pink.opacity(0.12), "BR")

                    // 中身
                    HStack(spacing: 8) {
                        
                        SelectAllTextField(
                            text: bindingForItemField(
                                itemId: item.id,
                                get: { $0.name },
                                set: { $0.name = $1 }
                            ),
                            placeholder: "材料",
                            shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .name,
                            config: .init(
                                onDidBecomeFirstResponder: { },
                                onCommit: { perform(.enterNext) },
                                internalFocus: .init(
                                    begin: { router.beginInternalFocusUpdate() },
                                    end:   { router.endInternalFocusUpdate() }
                                ),
                                focus: .init(
                                    rowId: item.id,
                                    field: .name,
                                    onReport: { id, field in
                                        router.reportFocused(rowId: id, field: field)
                                    }
                                ),
                                nav: .init(
                                    done:  { perform(.dismissKeyboard) },
                                    up:    { perform(.moveUp) },
                                    down:  { perform(.moveDown) },
                                    left:  { perform(.moveLeft) },
                                    right: { perform(.moveRight) }
                                )
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 30)

//                        .debugBG(DEBUG, Color.blue.opacity(0.6), "block")//✅
                        
                        
                        SelectAllTextField(
                            text: bindingForItemField(
                                itemId: item.id,
                                get: { $0.amount },
                                set: { $0.amount = $1 }
                            ),
                            placeholder: "分量",
                            shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .amount,
                            textAlignment: .right,           // ← 差分①
                            keyboardType: .decimalPad,       // ← 差分②
                            config: .init(
                                onCommit: { perform(.enterNext) },
                                internalFocus: .init(
                                    begin: { router.beginInternalFocusUpdate() },
                                    end:   { router.endInternalFocusUpdate() }
                                ),
                                focus: .init(
                                    rowId: item.id,
                                    field: .amount,          // ← 差分③
                                    onReport: { id, field in
                                        router.reportFocused(rowId: id, field: field)
                                    }
                                ),
                                nav: .init(
                                    done:  { perform(.dismissKeyboard) },
                                    up:    { perform(.moveUp) },
                                    down:  { perform(.moveDown) },
                                    left:  { perform(.moveLeft) },
                                    right: { perform(.moveRight) }
                                )
                            )
                        )
                        .frame(width: amountWidth, alignment: .trailing)



                        SelectAllTextField(
                            text: bindingForItemField(
                                itemId: item.id,
                                get: { $0.unit },
                                set: { $0.unit = $1 }
                        ),
                            placeholder: "単位",
                            shouldBecomeFirstResponder: router.current?.rowId == item.id && router.current?.field == .unit,
                            config: .init(
                                onDidBecomeFirstResponder: { },
                                onCommit: { perform(.enterNext) },
                                internalFocus: .init(
                                    begin: { router.beginInternalFocusUpdate() },
                                    end:   { router.endInternalFocusUpdate() }
                                ),
                                focus: .init(
                                    rowId: item.id,
                                    field: .unit,
                                    onReport: { id, field in
                                        router.reportFocused(rowId: id, field: field)
                                    }
                                ),
                                nav: .init(
                                    done:  { perform(.dismissKeyboard) },
                                    up:    { perform(.moveUp) },
                                    down:  { perform(.moveDown) },
                                    left:  { perform(.moveLeft) },
                                    right: { perform(.moveRight) }
                                )
                            )
                        )
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
private struct IngredientEnginePreviewContainer: View {
    @StateObject private var recipeStore = RecipeStore.previewStore()
    @StateObject private var store = IngredientEngineStore.previewStore()

    var body: some View {
        IngredientEngineView(
            recipeTitle: "材料",
            recipeStore: recipeStore,
            store: store)
    }
}

#Preview {
    NavigationStack {
        IngredientEnginePreviewContainer()
            .navigationTitle("Ingredients")
    }
}
#endif







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
                            .padding(4)
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
            title: "サンプルタイトル"
        )

        store.rows.append(.blockHeader(block))

        store.rows.append(
            .blockItem(.init(
                parentRecipeId: store.parentRecipeId,
                parentBlockId: block.id,
                name: "醤油",
                amount: "1234",
                unit: "大さじ１"
            ))
        )
        store.rows.append(
            .blockItem(.init(
                parentRecipeId: store.parentRecipeId,
                parentBlockId: block.id,
                name: "味醂",
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
