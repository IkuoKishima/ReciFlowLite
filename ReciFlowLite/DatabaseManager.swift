/// MARK: - DatabaseManager.swift

import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    static let shared = DatabaseManager()
    
    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "DatabaseManager") //安全のための直列キュー
    
    private init() {
        // 1. DBファイルパス
        let filemanager = FileManager.default
        let urls = filemanager.urls(for: .documentDirectory, in: .userDomainMask)
        let dbURL = urls[0].appendingPathComponent("ReciFlowLite.sqlite")
        
        DBLOG("📁 Database path: \(dbURL.path)")
        
        // 2. open
        var connection: OpaquePointer?
        if sqlite3_open(dbURL.path, &connection) == SQLITE_OK {
            DBLOG("✅ Database opend")
            self.db = connection
            // 3. テーブル作成
            createTablesIfNeeded()
            // 4. スキーマバージョンチェック（今はフックだけ）
            migrateIfNeeded()
        } else {
            DBLOG("❌ Failed to open database")
            self.db = nil
        }
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    // MARK: - スキーマ定義　＆　マイグレーション
    
    private func createTablesIfNeeded() {
        let sql = """
        CREATE TABLE IF NOT EXISTS recipes (
            id Text PRIMARY KEY,
            title TEXT NOT NULL,
            memo TEXT NOT NULL,
            createdAt REAL NOT NULL,
            updatedAt REAL NOT NULL,
            deletedAt REAL
        );
        """
        execute(sql: sql)
        // ingredientも起動時に用意しておく（呼び忘れ防止）
        createIngredientTablesIfNeeded()
    }
    
    /// 将来のための「マイグレーションフック」
    private func migrateIfNeeded() {
        let currentVersion = 2
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: "schemaVersion")

        // ✅ ここで実DBの状態をチェックして必要ならALTERする（UserDefaultsだけ更新しない）
        ensureRecipesDeletedAtColumn()

        if storedVersion == 0 {
            defaults.set(currentVersion, forKey: "schemaVersion")
            DBLOG("🔀 Schema initialized to \(currentVersion)")
            return
        }

        guard storedVersion < currentVersion else { return }

        // v2 migration (必要なら今後ここに追加)
        defaults.set(currentVersion, forKey: "schemaVersion")
        DBLOG("🔀 Schema migrated from \(storedVersion) to \(currentVersion)")
    }

    private func ensureRecipesDeletedAtColumn() {
        guard let db = db else { return }

        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            // PRAGMA table_info(recipes) でカラム一覧取得
            if sqlite3_prepare_v2(db, "PRAGMA table_info(recipes);", -1, &stmt, nil) != SQLITE_OK {
                DBLOG("❌ PRAGMA table_info(recipes) failed")
                return
            }

            var hasDeletedAt = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                // column name は index=1
                if let cName = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: cName)
                    if name == "deletedAt" { hasDeletedAt = true; break }
                }
            }

            guard !hasDeletedAt else { return }

            // 無ければ追加
            var err: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, "ALTER TABLE recipes ADD COLUMN deletedAt REAL;", nil, nil, &err) == SQLITE_OK {
                DBLOG("✅ ALTER TABLE recipes ADD COLUMN deletedAt")
            } else {
                let msg = err.map { String(cString: $0) } ?? "unknown"
                DBLOG("❌ ALTER TABLE failed: \(msg)")
                sqlite3_free(err)
            }
        }
    }




    
    // MARK: - 公開メソッド (Store から呼ぶ用)
    
    func fetchAllRecipes() async -> [Recipe] {
        guard let db = db else { return [] }

        return await withCheckedContinuation { continuation in
            queue.async {
                var result: [Recipe] = []

                let sql = """
                SELECT id, title, memo, createdAt, updatedAt
                FROM recipes
                WHERE deletedAt IS NULL
                ORDER BY createdAt DESC;
                """


                var statement: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(statement) }

                    while sqlite3_step(statement) == SQLITE_ROW {
                        if let recipe = DatabaseManager.readRecipeRow(statement: statement) {
                            result.append(recipe)
                        }
                    }
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ fetchAllRecipes prepare error: \(errorMsg)")
                }

                continuation.resume(returning: result)
            }
        }
    }


    
    func insert(recipe: Recipe) async -> Bool {
        guard let db = db else { return false }

        return await withCheckedContinuation { continuation in
            queue.async {
                let sql = """
                INSERT INTO recipes (id, title, memo, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?);
                """

                var statement: OpaquePointer?
                if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(statement) }

                    DatabaseManager.bind(recipe: recipe, to: statement)

                    if sqlite3_step(statement) == SQLITE_DONE {
                        DBLOG("✅ Inserted recipe: \(recipe.id)")
                        continuation.resume(returning: true)
                    } else {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ insert step error: \(errorMsg)")
                        continuation.resume(returning: false)
                    }
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ insert prepare error: \(errorMsg)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    
    
    // 注意: update は「変更確定」を意味する（閲覧ログではない）。
    // 閲覧ログが必要になったら viewedAt を別カラムで追加する。

    func update(recipe: Recipe) {
        guard let db = db else { return }


        let sql = """
        UPDATE recipes
        SET title = ?, memo = ?, updatedAt = ?
        WHERE id = ?;
        """

        queue.sync {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }

            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                // ✅ Swiftの文字列は SQLITE_TRANSIENT で安全に統一
                sqlite3_bind_text(statement, 1, recipe.title, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, recipe.memo,  -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 3, recipe.updatedAt.timeIntervalSince1970)
                sqlite3_bind_text(statement, 4, recipe.id.uuidString, -1, SQLITE_TRANSIENT)

                if sqlite3_step(statement) == SQLITE_DONE {
                    DBLOG("✅ Updated recipe: \(recipe.id)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ update step error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ update prepare error: \(errorMsg)")
            }
        }
    }

    
    
    //論理削除に変えるため、事故らないように名前を変える
    func softDelete(recipeID: UUID) {
        guard let db = db else { return }

        let sql = """
        UPDATE recipes
        SET deletedAt = ?, updatedAt = ?
        WHERE id = ?;
        """

        let now = Date().timeIntervalSince1970

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_double(statement, 1, now)
                sqlite3_bind_double(statement, 2, now)
                sqlite3_bind_text(statement, 3, recipeID.uuidString, -1, SQLITE_TRANSIENT)

                if sqlite3_step(statement) == SQLITE_DONE {
                    DBLOG("🗑 Soft deleted recipe: \(recipeID)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ softDelete error: \(errorMsg)")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    // Undo用に新たに追記
    func restore(recipeID: UUID) {
        guard let db = db else { return }

        let sql = """
        UPDATE recipes
        SET deletedAt = NULL, updatedAt = ?
        WHERE id = ?;
        """

        let now = Date().timeIntervalSince1970

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_double(statement, 1, now)
                sqlite3_bind_text(statement, 2, recipeID.uuidString, -1, SQLITE_TRANSIENT)

                if sqlite3_step(statement) == SQLITE_DONE {
                    DBLOG("♻️ Restored recipe: \(recipeID)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ restore error: \(errorMsg)")
                }
            }
            sqlite3_finalize(statement)
        }
    }

    
    // MARK: - 内部ヘルパー
    
    private func execute(sql: String) {
        guard let db = db else { return }

        queue.sync {
            var errorMessage: UnsafeMutablePointer<Int8>?
            if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
                if let errorMessage = errorMessage {
                    let message = String(cString: errorMessage)
                    DBLOG("❌ SQL exec error: \(message)")
                    sqlite3_free(errorMessage)
                }
            } else {
                // DBLOG("✅ SQL exec success")
            }
        }
    }
    
    private static func readRecipeRow(statement: OpaquePointer?) -> Recipe? {
        guard let stmt = statement else { return nil }

        // カラム index は SELECT の順番に対応
        guard
            let idCString = sqlite3_column_text(stmt, 0),
            let titleCString = sqlite3_column_text(stmt, 1),
            let memoCString = sqlite3_column_text(stmt, 2)
        else {
            return nil
        }

        let idString = String(cString: idCString)
        let title = String(cString: titleCString)
        let memo = String(cString: memoCString)

        let createdAtTime = sqlite3_column_double(stmt, 3)
        let updatedAtTime = sqlite3_column_double(stmt, 4)

        guard let id = UUID(uuidString: idString) else {
            return nil
        }

        return Recipe(
            id: id,
            title: title,
            memo: memo,
            createdAt: Date(timeIntervalSince1970: createdAtTime),
            updatedAt: Date(timeIntervalSince1970: updatedAtTime)
        )
    }
    
    private static func bind(recipe: Recipe, to stmt: OpaquePointer?) {
        guard let stmt else { return }

        sqlite3_bind_text(stmt, 1, recipe.id.uuidString, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, recipe.title,        -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, recipe.memo,         -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 4, recipe.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 5, recipe.updatedAt.timeIntervalSince1970)
    }

}


extension DatabaseManager {

    // rowKind: 0=single, 1=blockHeader, 2=blockItem
    enum IngredientRowKind: Int32 {
        case single = 0
        case blockHeader = 1
        case blockItem = 2
    }

    func createIngredientTablesIfNeeded() {
        guard let db = db else { return }

        let sql = """
        CREATE TABLE IF NOT EXISTS ingredient_rows (
            id TEXT PRIMARY KEY,
            recipeId TEXT NOT NULL,
            kind INTEGER NOT NULL,
            orderIndex INTEGER NOT NULL,
            blockId TEXT,
            title TEXT,
            name TEXT,
            amount TEXT,
            unit TEXT
        );
        """

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }
                if sqlite3_step(statement) != SQLITE_DONE {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ createIngredientTables error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ createIngredientTables prepare error: \(errorMsg)")
            }
        }
    }

    // MARK: - Public API

    /// v1（delete → insert）
    func replaceIngredientRows(recipeId: UUID, rows: [IngredientRow]) {
        guard let db = db else { return }

        queue.sync {
            var ok = true

            // 0) BEGIN
            if sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil) != SQLITE_OK {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ replaceIngredientRows BEGIN error: \(errorMsg)")
                return
            }

            // ✅ 成功したときだけCOMMIT / 失敗したらROLLBACK
            defer {
                if ok {
                    if sqlite3_exec(db, "COMMIT;", nil, nil, nil) != SQLITE_OK {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ replaceIngredientRows COMMIT error: \(errorMsg)")
                    }
                } else {
                    if sqlite3_exec(db, "ROLLBACK;", nil, nil, nil) != SQLITE_OK {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ replaceIngredientRows ROLLBACK error: \(errorMsg)")
                    }
                }
            }

            // 1) delete
            do {
                let delSQL = "DELETE FROM ingredient_rows WHERE recipeId = ?;"
                var delStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, delSQL, -1, &delStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(delStmt) }
                    sqlite3_bind_text(delStmt, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)

                    if sqlite3_step(delStmt) != SQLITE_DONE {
                        ok = false
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ replaceIngredientRows delete step error: \(errorMsg)")
                        return
                    }
                } else {
                    ok = false
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ replaceIngredientRows delete prepare error: \(errorMsg)")
                    return
                }
            }

            // 2) insert
            let insSQL = """
            INSERT INTO ingredient_rows
            (id, recipeId, kind, orderIndex, blockId, title, name, amount, unit)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """

            var insStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, insSQL, -1, &insStmt, nil) == SQLITE_OK {
                defer { sqlite3_finalize(insStmt) }

                for (index, row) in rows.enumerated() {
                    // orderIndex は現在の配列順を正とする
                    let orderIndex = index

                    let id: UUID
                    let kind: IngredientRowKind
                    var blockId: String? = nil
                    var title: String? = nil
                    var name: String? = nil
                    var amount: String? = nil
                    var unit: String? = nil

                    switch row {
                    case .single(let item):
                        id = item.id
                        kind = .single
                        name = item.name
                        amount = item.amount
                        unit = item.unit

                    case .blockHeader(let block):
                        id = block.id
                        kind = .blockHeader
                        title = block.title

                    case .blockItem(let item):
                        id = item.id
                        kind = .blockItem
                        blockId = item.parentBlockId?.uuidString
                        name = item.name
                        amount = item.amount
                        unit = item.unit
                    }

                    sqlite3_reset(insStmt)
                    sqlite3_clear_bindings(insStmt)

                    sqlite3_bind_text(insStmt, 1, id.uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_text(insStmt, 2, recipeId.uuidString, -1, SQLITE_TRANSIENT)
                    sqlite3_bind_int(insStmt, 3, kind.rawValue)
                    sqlite3_bind_int(insStmt, 4, Int32(orderIndex))

                    if let blockId {
                        sqlite3_bind_text(insStmt, 5, blockId, -1, SQLITE_TRANSIENT)
                    } else {
                        sqlite3_bind_null(insStmt, 5)
                    }

                    if let title {
                        sqlite3_bind_text(insStmt, 6, title, -1, SQLITE_TRANSIENT)
                    } else {
                        sqlite3_bind_null(insStmt, 6)
                    }

                    if let name {
                        sqlite3_bind_text(insStmt, 7, name, -1, SQLITE_TRANSIENT)
                    } else {
                        sqlite3_bind_null(insStmt, 7)
                    }

                    if let amount {
                        sqlite3_bind_text(insStmt, 8, amount, -1, SQLITE_TRANSIENT)
                    } else {
                        sqlite3_bind_null(insStmt, 8)
                    }

                    if let unit {
                        sqlite3_bind_text(insStmt, 9, unit, -1, SQLITE_TRANSIENT)
                    } else {
                        sqlite3_bind_null(insStmt, 9)
                    }

                    if sqlite3_step(insStmt) != SQLITE_DONE {
                        ok = false
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ replaceIngredientRows insert step error: \(errorMsg)")
                        return
                    }
                }
            } else {
                ok = false
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ replaceIngredientRows insert prepare error: \(errorMsg)")
                return
            }
        }
    }

    
}
extension DatabaseManager {

    func fetchIngredientRows(recipeId: UUID) async -> [IngredientRow] {
        await withCheckedContinuation { cont in
            queue.async { [weak self] in
                guard let self else {
                    cont.resume(returning: [])
                    return
                }
                let rows = self._fetchIngredientRowsSync(recipeId: recipeId)
                cont.resume(returning: rows)
            }
        }
    }

    // 既存の中身を _fetchIngredientRowsSync に移す（queue.sync を消す）
    private func _fetchIngredientRowsSync(recipeId: UUID) -> [IngredientRow] {
       
            guard let db = db else { return [] }

            let sql = """
            SELECT id, kind, orderIndex, blockId, title, name, amount, unit
            FROM ingredient_rows
            WHERE recipeId = ?
            ORDER BY orderIndex ASC;
            """

            var result: [IngredientRow] = []

            // ✅ 直にDB処理を書く（＝あなたの中身をそのまま置く）
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }

                sqlite3_bind_text(statement, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)

                while sqlite3_step(statement) == SQLITE_ROW {
                    guard
                        let idC = sqlite3_column_text(statement, 0)
                    else { continue }

                    let kindRaw = sqlite3_column_int(statement, 1) 
                    let kind = DatabaseManager.IngredientRowKind(rawValue: kindRaw) ?? .single

                    let orderIndex = Int(sqlite3_column_int(statement, 2))

                    let blockIdStr: String? = {
                        guard let c = sqlite3_column_text(statement, 3) else { return nil }
                        let s = String(cString: c)
                        return s.isEmpty ? nil : s
                    }()

                    let title: String = {
                        guard let c = sqlite3_column_text(statement, 4) else { return "" }
                        return String(cString: c)
                    }()

                    let name: String = {
                        guard let c = sqlite3_column_text(statement, 5) else { return "" }
                        return String(cString: c)
                    }()

                    let amount: String = {
                        guard let c = sqlite3_column_text(statement, 6) else { return "" }
                        return String(cString: c)
                    }()

                    let unit: String = {
                        guard let c = sqlite3_column_text(statement, 7) else { return "" }
                        return String(cString: c)
                    }()

                    let id = UUID(uuidString: String(cString: idC)) ?? UUID()

                    switch kind {
                    case .blockHeader:
                        DBLOG("""
                        🧩 blockHeader loaded
                           blockId: \(id)
                           title: \(title)
                        """)

                        let block = IngredientBlock(
                            id: id,
                            parentRecipeId: recipeId,
                            orderIndex: orderIndex,
                            title: title
                        )
                        result.append(.blockHeader(block))

                    case .single:
                        let item = IngredientItem(
                            id: id,
                            parentRecipeId: recipeId,
                            parentBlockId: nil,
                            orderIndex: orderIndex,
                            name: name,
                            amount: amount,
                            unit: unit
                        )
                        result.append(.single(item))

                    case .blockItem:
                        let pbid = blockIdStr.flatMap(UUID.init(uuidString:))

                        DBLOG("""
                        🧱 blockItem loaded
                           itemId: \(id)
                           parentBlockId: \(pbid?.uuidString ?? "nil")
                           name: \(name)
                        """)

                        let item = IngredientItem(
                            id: id,
                            parentRecipeId: recipeId,
                            parentBlockId: pbid,
                            orderIndex: orderIndex,
                            name: name,
                            amount: amount,
                            unit: unit
                        )
                        result.append(.blockItem(item))
                    }
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ fetchIngredientRows prepare error: \(errorMsg)")
            }

            return result
        }
}
