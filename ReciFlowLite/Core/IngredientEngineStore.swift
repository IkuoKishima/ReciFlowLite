/// MARK: - IngredientEngineStore.swift
//🟨 ここを司令塔にする(状態を持っているのはここ、Viewは参照しているだけ）

import Foundation
import UIKit

final class IngredientEngineStore: ObservableObject {
    @Published var rows: [IngredientRow] = []
    
    // ✅ グローバルレール（最後に選択されたrow.id）
    @Published var globalRailRowId: UUID? = nil
    @Published var blockInsertAnchorId: [UUID: UUID] = [:]   // blockId -> rowId
    
    private(set) var parentRecipeId: UUID
    
    // ✅ 追加：未保存変更フラグ
    @Published private(set) var isDirty: Bool = false

    // ✅ 追加：デバウンス保存用
    private var saveWorkItem: DispatchWorkItem?
    private let debounceSeconds: TimeInterval = 0.6
    
    @Published var pendingFocusItemId: UUID? = nil //追加アイテムに即フォーカスさせるためidを持たせる
    

    
    // MARK: - 初期化処理
    
    init(parentRecipeId: UUID) {
        self.parentRecipeId = parentRecipeId
    }
    
    
    // ✅ 追加：変更が起きたら呼ぶ（＝保存予約）
    func markDirtyAndScheduleSave(reason: String = "") {
        isDirty = true

        // 直前の予約をキャンセルして「最後の操作から一定時間後に保存」
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.saveNow(force: false)
        }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceSeconds, execute: work)

        #if DEBUG
        if !reason.isEmpty { print("🟨 markDirty: \(reason)") }
        #endif
    }
    
    // ✅ 追加：即時保存（バックグラウンド/画面離脱など）
    func flushSave(reason: String = "") {
        saveWorkItem?.cancel()
        saveWorkItem = nil
        saveNow(force: true)

        #if DEBUG
        if !reason.isEmpty { print("🟧 flushSave: \(reason)") }
        #endif
    }
    
    // MARK: - 保存（既存を少しだけ改造）
    func saveNow(force: Bool = false) {
        // 「変更がないなら保存しない」＝もたつき軽減
        if !force, !isDirty { return }

        DatabaseManager.shared.createIngredientTablesIfNeeded()
        DatabaseManager.shared.replaceIngredientRows(
            recipeId: parentRecipeId,
            rows: rows
        )

        isDirty = false

        #if DEBUG
        print("✅ saved \(rows.count) rows (force=\(force))")
        #endif
    }
    
    
    // 🔀loadIfNeeded()を使わないでDB読み込み検証をするための記述

    // MARK: - 読込（破壊テスト用：毎回DBから復元）
//    func load() {
//        #if DEBUG
//        print("🟦 load start recipeId=\(parentRecipeId)")
//        #endif
//
//        DatabaseManager.shared.createIngredientTablesIfNeeded()
//        #if DEBUG
//        print("🟦 fetchIngredientRows start")
//        #endif
//        let loaded = DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)
//        #if DEBUG
//        print("🟦 fetchIngredientRows end count=\(loaded.count)")
//        #endif
//
//        rows = loaded
//        reindexAll()// ← Liteでは必須（DB整合保証）
//        // ✅ レール初期化（unitRange方式の基準）
//        globalRailRowId = rows.last?.id
//
//        blockInsertAnchorId = [:]
//        for row in rows {
//            if case .blockItem(let item) = row, let blockId = item.parentBlockId {
//                blockInsertAnchorId[blockId] = row.id// ブロックごとの“最後にある行”をレールに
//            }
//        }
//
//        // ✅ load直後は「保存済み状態」扱いにする
//        isDirty = false
//    }


    
    

    // MARK: - 読込（実践ビルド用）
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
        
        Task {
            DatabaseManager.shared.createIngredientTablesIfNeeded()
            let loaded = await DatabaseManager.shared.fetchIngredientRows(recipeId: parentRecipeId)
            await MainActor.run {
                
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
                    
                    // ✅ load() と同じ“整合”を必ず実行
                    reindexAll()
                    globalRailRowId = rows.last?.id
                    
                    blockInsertAnchorId = [:]
                    for row in rows {
                        if case .blockItem(let item) = row, let blockId = item.parentBlockId {
                            blockInsertAnchorId[blockId] = row.id
                        }
                    }
                    
                    isDirty = false
                    return
                }
                
                // ✅ DBが空＝“初回”の扱い
                // 本番は seed を入れない（勝手に材料が入る事故を防ぐ）
                rows = [.single(.init(parentRecipeId: parentRecipeId))]
                reindexAll()
                globalRailRowId = rows.last?.id
                blockInsertAnchorId = [:]
                isDirty = false
                
                #if DEBUG
                print("🟦 first seed: one empty single row")
                #endif
            }
        }
    }
}

// MARK: - 追加API（v15準拠：入力で増えない / 追加はドック起点）

extension IngredientEngineStore {

    
    // ✅ このindexが属する「ユニット（single or block）」範囲を返す
    func unitRange(at index: Int) -> Range<Int> {
        guard rows.indices.contains(index) else { return index..<index }

        switch rows[index] {

        case .single:
            return index ..< (index + 1)

        case .blockHeader(let block):
            var end = index + 1
            while end < rows.count {
                if case .blockItem(let item) = rows[end], item.parentBlockId == block.id {
                    end += 1
                } else {
                    break
                }
            }
            return index ..< end

        case .blockItem(let item):
            // blockItem から呼ばれたら、対応する header を探してそこから範囲を返す
            var headerIndex = index - 1
            while headerIndex >= 0 {
                if case .blockHeader(let block) = rows[headerIndex], block.id == item.parentBlockId {
                    return unitRange(at: headerIndex)
                }
                headerIndex -= 1
            }
            return index ..< (index + 1) // 安全策
        }
    }
    
    
    
    //アンカー更新ルール（重要）の追加
    
    // ✅　選択更新：グローバルレール（最後に選択されたrow.id）
    func userDidSelectRow(_ rowId: UUID) {
        globalRailRowId = rowId
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
    
    
    
    

    
    
    // 挿入本体：これで 「ブロックヘッダとブロックアイテムの間に割り込む」現象は、論理的に起きない
    /// ✅ グローバル＋：選択ユニットの「末尾」に single を入れる
    @discardableResult
    func addSingleAtGlobalRail() -> Int {
        let newItem = IngredientItem(parentRecipeId: parentRecipeId)

        // 選択が無い → 末尾
        guard let railId = globalRailRowId,
                let selectedIndex = rows.firstIndex(where: { $0.id == railId })
        else {
            rows.append(.single(newItem))
            let inserted = rows.count - 1
            globalRailRowId = rows[inserted].id
            return inserted
        }

        // ✅ 選択ユニット範囲の末尾（upperBound）に挿入
        let range = unitRange(at: selectedIndex)
        let insertIndex = range.upperBound

        rows.insert(.single(newItem), at: insertIndex)
        reindexAll()
        // レールも新規行へ
        globalRailRowId = rows[insertIndex].id
        // ✅ 追加
        markDirtyAndScheduleSave(reason: "addSingleAtGlobalRail")
        return insertIndex
    }
    
    // グローバル2x2　ブロックヘッダも同じ規則で固定
    @discardableResult
    func addBlockHeaderAtGlobalRail() -> Int {
        let newBlock = IngredientBlock(parentRecipeId: parentRecipeId, orderIndex: 0, title: "調合")

        guard let railId = globalRailRowId,
                let selectedIndex = rows.firstIndex(where: { $0.id == railId })
        else {
            rows.append(.blockHeader(newBlock))
            let inserted = rows.count - 1
            globalRailRowId = rows[inserted].id
            markDirtyAndScheduleSave(reason: "addBlockHeaderAtGlobalRail") // ←ここも
            return inserted
        }

        let range = unitRange(at: selectedIndex)
        let insertIndex = range.upperBound

        rows.insert(.blockHeader(newBlock), at: insertIndex)
        reindexAll()
        globalRailRowId = rows[insertIndex].id
        markDirtyAndScheduleSave(reason: "addBlockHeaderAtGlobalRail") // ←追加
        return insertIndex
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
    
    

    

    
    
 
    
    // Public API（プライベートと対義語の、誰でも使える・アプリケーション・プログラム・インターフェース）
// MARK: - 行追加の中枢
    
    /// ＋：single を追加（追加位置は「タップ行の直後」／nilなら末尾）
    /// - Returns: 挿入された rows index（フォーカス合わせに使える）
    @discardableResult
    func addSingle(after index: Int?) -> Int {
        let insertAt = insertionIndex(after: index)

        let newItem = IngredientItem(
            id: UUID(),
            parentRecipeId: parentRecipeId,
            parentBlockId: nil,
            orderIndex: 0,
            name: "",
            amount: "",
            unit: ""
        )

        rows.insert(.single(newItem), at: insertAt)
        pendingFocusItemId = newItem.id
        
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
            id: UUID(),
            parentRecipeId: parentRecipeId,
            parentBlockId: blockId,
            orderIndex: 0,
            name: "",
            amount: "",
            unit: ""
        )

        rows.insert(.blockItem(newItem), at: insertAt)
        pendingFocusItemId = newItem.id
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
        flushSave(reason: "deleteRow")// ✅ deleteだけ即保存
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

