//🟨 ここを司令塔にする(状態を持っているのはここ、Viewは参照しているだけ）

import Foundation

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []
    
    // ✅ v15の「レール」：追加の基準を保持
    @Published var globalInsertAnchorId: UUID? = nil
    @Published var blockInsertAnchorId: [UUID: UUID] = [:]   // blockId -> rowId
    
    

    private(set) var parentRecipeId: UUID

    init(parentRecipeId: UUID) {
        self.parentRecipeId = parentRecipeId
    }

    // MARK: - 読込
    
//    func loadIfNeeded() {
//        #if DEBUG
//        print("🟦 loadIfNeeded start recipeId=\(parentRecipeId)")
//        #endif
//
//        if !rows.isEmpty {
//            #if DEBUG
//            print("🟦 loadIfNeeded early return (rows already exist) count=\(rows.count)")
//            #endif
//            return
//        }
//
//        DatabaseManager.shared.createIngredientTablesIfNeeded()
//
//        #if DEBUG
//        print("🟦 fetchIngredientRows start")
//        #endif
//
//        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)
//
//        #if DEBUG
//        print("🟦 fetchIngredientRows end count=\(loaded.count)")
//        #endif
//        if !loaded.isEmpty {
//            rows = loaded
//            return
//        }
//
//        // v1: 初回だけ最小の種
//        let block = IngredientBlock(
//            parentRecipeId: parentRecipeId,
//            orderIndex: 2,
//            title: "調合"
//        )
//
//        rows = [
//            .single(.init(parentRecipeId: parentRecipeId, name: "酒", amount: "012345", unit: "ml")),
//            .single(.init(parentRecipeId: parentRecipeId, name: "醤油", amount: "15", unit: "0123")),
//
//            .blockHeader(block),
//
//            .blockItem(.init(
//                parentRecipeId: parentRecipeId,
//                parentBlockId: block.id,     // ✅ 束に属する
//                name: "砂糖", amount: "012345", unit: "0123"
//            )),
//            .blockItem(.init(
//                parentRecipeId: parentRecipeId,
//                parentBlockId: block.id,     // ✅ 束に属する
//                name: "塩", amount: "1", unit: "tsp"
//            )),
//
//            .single(.init(parentRecipeId: parentRecipeId, name: "塩", amount: "1", unit: "tsp")),
//            .single(.init(parentRecipeId: parentRecipeId, name: "", amount: "", unit: ""))
//        ]
//    }
    
    // 🔀loadIfNeeded()を使わないでDB読み込み検証をするための記述
    // MARK: - 読込（破壊テスト用：毎回DBから復元）
    func load() {
        #if DEBUG
        print("🟦 load start recipeId=\(parentRecipeId)")
        #endif

        DatabaseManager.shared.createIngredientTablesIfNeeded()

        #if DEBUG
        print("🟦 fetchIngredientRows start")
        #endif

        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)

        #if DEBUG
        print("🟦 fetchIngredientRows end count=\(loaded.count)")
        #endif

        rows = loaded
        reindexAll()   // ← Liteでは必須（DB整合保証）
        // ✅ レール初期化（復元後の rows に合わせる）
        globalInsertAnchorId = rows.last?.id

        blockInsertAnchorId = [:]
        for row in rows {
            if case .blockItem(let item) = row, let blockId = item.parentBlockId {
                blockInsertAnchorId[blockId] = row.id   // ブロックごとの“最後にある行”をレールに
            }
        }

    }

    


    // MARK: - 保存
    
    func saveNow() {
        DatabaseManager.shared.createIngredientTablesIfNeeded()
        DatabaseManager.shared.replaceIngredientRows(
            recipeId: parentRecipeId,
            rows: rows
        )
        //保存した責任側がログを出す方が好まれる書き方
        #if DEBUG
        print("✅ saved \(rows.count) rows")
        #endif
    }
    
   
}
// MARK: - 追加API（v15準拠：入力で増えない / 追加はドック起点）

extension IngredientEngineStore {


    /// rows配列の安全な「挿入先index」を作る
    /// - after: nil なら末尾、指定があれば「その直後」に挿入
    private func insertionIndex(after index: Int?) -> Int {
        guard let index else { return rows.count }
        let next = index + 1
        return min(max(next, 0), rows.count)
    }

    /// rows配列順 = orderIndex を必ず成立させる
    private func reindexAll() {
        for i in rows.indices {
            switch rows[i] {
            case .single(var item):
                item.orderIndex = i
                rows[i] = .single(item)

            case .blockItem(var item):
                item.orderIndex = i
                rows[i] = .blockItem(item)

            case .blockHeader(var block):
                block.orderIndex = i
                rows[i] = .blockHeader(block)
            }
        }
    }

    /// 指定ブロックの「ブロック内末尾の index」を返す（無ければ header の index）
    private func lastIndexInBlock(blockId: UUID) -> Int? {
        var last: Int? = nil
        for (i, row) in rows.enumerated() {
            if case .blockItem(let item) = row, item.parentBlockId == blockId {
                last = i
            }
        }
        if let last { return last }

        // blockItem が無いなら blockHeader の位置にフォールバック
        for (i, row) in rows.enumerated() {
            if case .blockHeader(let block) = row, block.id == blockId {
                return i
            }
        }
        return nil
    }
    
    

    
//アンカー更新ルール（重要）の追加
    // ✅ ユーザーが行を触った時の「レール更新」
    func userDidSelectRow(_ rowId: UUID) {
        globalInsertAnchorId = rowId
    }

    // ✅ ブロック内操作の「レール更新」（globalは汚さない）
    func userDidSelectRowInBlock(blockId: UUID, rowId: UUID) {
        blockInsertAnchorId[blockId] = rowId
    }

    // rowId -> index 解決（直前に必ずこれで確定させる）
    func indexOfRow(id: UUID?) -> Int? {
        guard let id else { return nil }
        return rows.firstIndex(where: { $0.id == id })
    }
  

    
    @discardableResult
        func addSingleAtGlobalRail() -> Int {
            let afterIndex = indexOfRow(id: globalInsertAnchorId)
            let inserted = addSingle(after: afterIndex)
            // ✅ v15: single追加は global rail を更新してよい
            globalInsertAnchorId = rows[inserted].id
            return inserted
        }
    
    @discardableResult
        func addBlockHeaderAtGlobalRail() -> Int {
            let afterIndex = indexOfRow(id: globalInsertAnchorId)
            let headerIndex = addBlock(after: afterIndex)   // ✅ ヘッダのみ追加（地雷回避）
            // ✅ v15: 2x2(ヘッダ)追加は global rail を更新してよい
            globalInsertAnchorId = rows[headerIndex].id
            return headerIndex
        }
    
    @discardableResult
        func addBlockItemAtBlockRail(blockId: UUID) -> Int {
            let afterIndex = indexOfRow(id: blockInsertAnchorId[blockId])
            let inserted = addBlockItem(blockId: blockId, after: afterIndex)

            // ✅ block rail は更新する
            blockInsertAnchorId[blockId] = rows[inserted].id

            // ❌ global rail は更新しない（←ここがv15の“流れ維持”の核）
            return inserted
        }
    
    
 
    
    // Public API（プライベートと対義語の、誰でも使える・アプリケーション・プログラム・インターフェース）
// MARK: - 行追加の中枢
    
    /// ＋：single を追加（追加位置は「タップ行の直後」／nilなら末尾）
    /// - Returns: 挿入された rows index（フォーカス合わせに使える）
    @discardableResult
    func addSingle(after index: Int?) -> Int {
        let insertAt = insertionIndex(after: index)

        let newItem = IngredientItem(
            parentRecipeId: parentRecipeId,
            parentBlockId: nil,
            orderIndex: 0,
            name: "S",
            amount: "",
            unit: ""
        )

        rows.insert(.single(newItem), at: insertAt)
        reindexAll()

        #if DEBUG
        print("✅ addSingle insertAt=\(insertAt) rows=\(rows.count)")
        #endif

        return insertAt
    }

    /// 2x2：Liteは「headerのみ追加」で固定（⚠️初期item同時生成は事故るため⚠️）
    /// - Returns: 初期 blockItem の rows index（フォーカス合わせに使える）
    @discardableResult
    func addBlock(after index: Int?) -> Int {
        let headerAt = insertionIndex(after: index)

        let block = IngredientBlock(
            parentRecipeId: parentRecipeId,
            orderIndex: 0,
            title: "調合"
        )

        rows.insert(.blockHeader(block), at: headerAt)
        reindexAll()

        #if DEBUG
        print("✅ addBlock(header only) headerAt=\(headerAt) blockId=\(block.id)")
        #endif

        return headerAt
    }

    //🟡block内＋：指定 blockId の配下に blockItem を追加
    /// - after: nil なら「そのブロックの末尾」に追加（推奨・事故りにくい）
    /// - Returns: 挿入された rows index
    @discardableResult
    func addBlockItem(blockId: UUID, after indexInBlock: Int? = nil) -> Int {
        // 基本は「ブロック末尾」に追加
        var baseIndex: Int? = lastIndexInBlock(blockId: blockId)

        // もし「ブロック内の任意行直後」を使いたいなら上書き
        if let idx = indexInBlock, rows.indices.contains(idx) {
            // 指定行が同じブロックの blockItem ならその直後
            if case .blockItem(let item) = rows[idx], item.parentBlockId == blockId {
                baseIndex = idx
            }
        }

        // 2) baseIndex の直後に挿入
        let insertAt = insertionIndex(after: baseIndex)

        let newItem = IngredientItem(
            parentRecipeId: parentRecipeId,
            parentBlockId: blockId,
            orderIndex: 0,
            name: "B",
            amount: "",
            unit: ""
        )

        rows.insert(.blockItem(newItem), at: insertAt)
        reindexAll()

        #if DEBUG
        print("✅ addBlockItem blockId=\(blockId) insertAt=\(insertAt) rows=\(rows.count)")
        #endif

        return insertAt
    }
    
    
    
    
    
// MARK: - 行削除（delete ボタン用の中枢）
    
    func deleteRow(at index: Int) {
        guard rows.indices.contains(index) else { return }

        switch rows[index] {
        case .single, .blockItem: // 単体行は 1 行だけ削除　ブロック内はヘッダは残る
            rows.remove(at: index)
            

        case .blockHeader(let block):
            // ブロックヘッダ＋同じ blockId を持つ blockItem をまとめて削除
            deleteBlock(blockId: block.id, startingAt: index)
        }
        reindexAll()   // ⚠️orderIndex をDB保存に使うので、delete後に reindexAll() は必須
    }
    
    

    private func deleteBlock(blockId: UUID, startingAt headerIndex: Int) {
        guard rows.indices.contains(headerIndex) else { return }
        
        var endIndex = headerIndex + 1
        
        // headerIndex の直後から、
        // 「同じ blockId を持つ blockItem が連続している範囲」を探す
        while endIndex < rows.count {
            if case .blockItem(let item) = rows[endIndex],
               item.parentBlockId == blockId {
                // 同じブロックの中身なので、削除範囲を1つ伸ばす
                endIndex += 1
            } else {
                // 別ブロックヘッダ or .single or 他の blockItem が来たら終了
                break
            }
        }
        
        // [ヘッダ ..< 連続 blockItem の終端] をまとめて削除
        rows.removeSubrange(headerIndex ..< endIndex)
        
        
        //どのブロックが“ローカル並び替えモード”なのか」を示す状態（UI制御用）の時に必要な保険、
        //@Published var localReorderBlockId: UUID?と一緒に使う
//        if localReorderBlockId == blockId {
//            localReorderBlockId = nil
//        }
        
    }
    
}

