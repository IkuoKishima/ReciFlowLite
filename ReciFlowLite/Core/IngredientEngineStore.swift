//🟨 ここを司令塔にする(状態を持っているのはここ、Viewは参照しているだけ）

import Foundation

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []

    private(set) var parentRecipeId: UUID

    init(parentRecipeId: UUID) {
        self.parentRecipeId = parentRecipeId
    }

    // MARK: - 読込
    
    func loadIfNeeded() {
        #if DEBUG
        print("🟦 loadIfNeeded start recipeId=\(parentRecipeId)")
        #endif

        if !rows.isEmpty {
            #if DEBUG
            print("🟦 loadIfNeeded early return (rows already exist) count=\(rows.count)")
            #endif
            return
        }

        DatabaseManager.shared.createIngredientTablesIfNeeded()

        #if DEBUG
        print("🟦 fetchIngredientRows start")
        #endif

        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)

        #if DEBUG
        print("🟦 fetchIngredientRows end count=\(loaded.count)")
        #endif
        if !loaded.isEmpty {
            rows = loaded
            return
        }

        // v1: 初回だけ最小の種
        let block = IngredientBlock(
            parentRecipeId: parentRecipeId,
            orderIndex: 2,
            title: "合わせ調味料"
        )

        rows = [
            .single(.init(parentRecipeId: parentRecipeId, name: "酒", amount: "012345", unit: "ml")),
            .single(.init(parentRecipeId: parentRecipeId, name: "醤油", amount: "15", unit: "0123")),

            .blockHeader(block),

            .blockItem(.init(
                parentRecipeId: parentRecipeId,
                parentBlockId: block.id,     // ✅ 束に属する
                name: "砂糖", amount: "012345", unit: "0123"
            )),
            .blockItem(.init(
                parentRecipeId: parentRecipeId,
                parentBlockId: block.id,     // ✅ 束に属する
                name: "塩", amount: "1", unit: "tsp"
            )),

            .single(.init(parentRecipeId: parentRecipeId, name: "塩", amount: "1", unit: "tsp")),
            .single(.init(parentRecipeId: parentRecipeId, name: "", amount: "", unit: ""))
        ]
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

    // MARK: - Public API

    /// ＋：single を追加（追加位置は「タップ行の直後」／nilなら末尾）
    /// - Returns: 挿入された rows index（フォーカス合わせに使える）
    @discardableResult
    func addSingle(after index: Int?) -> Int {
        let insertAt = insertionIndex(after: index)

        let newItem = IngredientItem(
            parentRecipeId: parentRecipeId,
            parentBlockId: nil,
            orderIndex: 0,
            name: "",
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

    /// 2x2：blockHeader + 初期 blockItem を追加（2行挿入）
    /// - Returns: 初期 blockItem の rows index（フォーカス合わせに使える）
    @discardableResult
    func addBlock(after index: Int?) -> Int {
        let headerAt = insertionIndex(after: index)

        let block = IngredientBlock(
            parentRecipeId: parentRecipeId,
            orderIndex: 0,
            title: "合わせ調味料"
        )

        rows.insert(.blockHeader(block), at: headerAt)
        reindexAll()

        #if DEBUG
        print("✅ addBlock(header only) headerAt=\(headerAt) blockId=\(block.id)")
        #endif

        return headerAt
    }

    /// block内＋：指定 blockId の配下に blockItem を追加
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

        let insertAt = insertionIndex(after: baseIndex)

        let newItem = IngredientItem(
            parentRecipeId: parentRecipeId,
            parentBlockId: blockId,
            orderIndex: 0,
            name: "",
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
}


//import Foundation
//
//final class IngredientEngineStore: ObservableObject {
//    @Published var rows: [IngredientRow] = []
//    
//    //✅Engineから呼び出す仮データ　seedIfNeeded（必要に応じてタネを撒く）
//    func seedIfNeeded() {
//        if rows.isEmpty {
//            let block = IngredientBlock(
//                id: UUID(),
//                title: "合わせ調味料"
//            )
//            rows = [
//                .single(.init(name: "酒", amount: "012345", unit: "ml")),
//                .single(.init(name: "醤油", amount: "15", unit: "0123")),
//                .blockHeader(block),
//                .blockItem(.init(name: "砂糖", amount: "012345", unit: "0123")),
//                .blockItem(.init(name: "塩", amount: "1", unit: "tsp")),
//                .single(.init(name: "塩", amount: "1", unit: "tsp"))
//            ]
//        }
//    }
//}

//enum IngredientRow: Identifiable, Equatable {
//    case single(IngredientItem)
//    case blockHeader(IngredientBlock)
//    case blockItem(IngredientItem)
//
//    var id: UUID {
//        switch self {
//        case .single(let i): return i.id
//        case .blockHeader(let b): return b.id
//        case .blockItem(let i): return i.id
//        }
//    }
//}

//struct IngredientItem: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var name: String = ""
//    var amount: String = ""
//    var unit: String = ""
//}

//struct IngredientBlock: Identifiable, Equatable {
//    var id: UUID = UUID()
//    var title: String = ""
//}




