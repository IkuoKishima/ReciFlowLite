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
        
        print("📁 Database path: \(dbURL.path)")
        
        // 2. open
        var connection: OpaquePointer?
        if sqlite3_open(dbURL.path, &connection) == SQLITE_OK {
            print("✅ Database opend")
            self.db = connection
            // 3. テーブル作成
            createTablesIfNeeded()
            // 4. スキーマバージョンチェック（今はフックだけ）
            migrateIfNeeded()
        } else {
            print("❌ Failed to open database")
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
            updatedAt REAL NOT NULL
        );
        """
        
        execute(sql: sql)
    }
    
    /// 将来のための「マイグレーションフック」
    private func migrateIfNeeded() {
        let currentVersion = 1  // ← 今回の Lite 初期スキーマを「バージョン1」とする

        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: "schemaVersion") // 未設定なら 0

        guard storedVersion < currentVersion else {
            // すでに最新 or それ以上。今回は何もしない
            return
        }

        // ここでバージョンごとの移行処理を書く
        // 例）if storedVersion < 2 { ALTER TABLE ...; }
        // 今回は v1 なので何もしない

        defaults.set(currentVersion, forKey: "schemaVersion")
        print("🔀 Schema migrated from \(storedVersion) to \(currentVersion)")
    }
    
    // MARK: - 公開メソッド (Store から呼ぶ用)
    
    func fetchAllRecipes() -> [Recipe] {
        guard let db = db else { return [] }

        var result: [Recipe] = []

        let sql = """
        SELECT id, title, memo, createdAt, updatedAt
        FROM recipes
        ORDER BY createdAt DESC;
        """

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }

                while sqlite3_step(statement) == SQLITE_ROW {
                    if let recipe = readRecipeRow(statement: statement) {
                        result.append(recipe)
                    }
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("❌ fetchAllRecipes prepare error: \(errorMsg)")
            }
        }

        return result
    }

    
    func insert(recipe: Recipe) {
        guard let db = db else { return }

        let sql = """
        INSERT INTO recipes (id, title, memo, createdAt, updatedAt)
        VALUES (?, ?, ?, ?, ?);
        """

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                bind(recipe: recipe, to: statement)
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ Inserted recipe: \(recipe.id)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    print("❌ insert error: \(errorMsg)")
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    
    
    // 注意: update は「変更確定」を意味する（閲覧ログではない）。
    // 閲覧ログが必要になったら viewedAt を別カラムで追加する。

    func update(recipe: Recipe) {
        guard let db = db else { return }

        let sql = """
        UPDATE recipes
        SET title = ?, memo = ?, createdAt = ?, updatedAt = ?
        WHERE id = ?;
        """

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                // バインドの順番に注意（SQLの ? の順）
                sqlite3_bind_text(statement, 1, (recipe.title as NSString).utf8String, -1, nil)
                sqlite3_bind_text(statement, 2, (recipe.memo as NSString).utf8String, -1, nil)
                sqlite3_bind_double(statement, 3, recipe.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(statement, 4, recipe.updatedAt.timeIntervalSince1970)
                sqlite3_bind_text(statement, 5, (recipe.id.uuidString as NSString).utf8String, -1, nil)

                if sqlite3_step(statement) == SQLITE_DONE {
                    print("✅ Updated recipe: \(recipe.id)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    print("❌ update error: \(errorMsg)")
                }
            }
            sqlite3_finalize(statement)
        }
    }
    
    func delete(recipeID: UUID) {
        guard let db = db else { return }

        let sql = "DELETE FROM recipes WHERE id = ?;"

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (recipeID.uuidString as NSString).utf8String, -1, nil)
                if sqlite3_step(statement) == SQLITE_DONE {
                    print("🗑 Deleted recipe: \(recipeID)")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    print("❌ delete error: \(errorMsg)")
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
                    print("❌ SQL exec error: \(message)")
                    sqlite3_free(errorMessage)
                }
            } else {
                // print("✅ SQL exec success")
            }
        }
    }
    
    private func readRecipeRow(statement: OpaquePointer?) -> Recipe? {
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
    
    private func bind(recipe: Recipe, to statement: OpaquePointer?) {
        guard let stmt = statement else { return }

        sqlite3_bind_text(stmt, 1, (recipe.id.uuidString as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (recipe.title as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (recipe.memo as NSString).utf8String, -1, nil)
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
                    print("❌ createIngredientTables error: \(errorMsg)")
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("❌ createIngredientTables prepare error: \(errorMsg)")
            }
        }
    }

    // MARK: - Public API

    func fetchIngredientRows(recipeId: UUID) -> [IngredientRow] {
        guard let db = db else { return [] }

        let sql = """
        SELECT id, kind, orderIndex, blockId, title, name, amount, unit
        FROM ingredient_rows
        WHERE recipeId = ?
        ORDER BY orderIndex ASC;
        """

        var result: [IngredientRow] = []

        queue.sync {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                defer { sqlite3_finalize(statement) }

                sqlite3_bind_text(statement, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)

                while sqlite3_step(statement) == SQLITE_ROW {
                    guard
                        let idC = sqlite3_column_text(statement, 0),
                        let kindC = sqlite3_column_int(statement, 1) as Int32?
                    else { continue }

                    let id = UUID(uuidString: String(cString: idC)) ?? UUID()
                    let kind = IngredientRowKind(rawValue: kindC) ?? .single
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

                    switch kind {
                    case .blockHeader:
                        #if DEBUG
                        print("""
                        🧩 blockHeader loaded
                           blockId: \(id)
                           title: \(title)
                        """)
                        #endif

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

                        #if DEBUG
                        print("""
                        🧱 blockItem loaded
                           itemId: \(id)
                           parentBlockId: \(pbid?.uuidString ?? "nil")
                           name: \(name)
                        """)
                        #endif

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
                print("❌ fetchIngredientRows prepare error: \(errorMsg)")
            }
        }

        return result
    }

    /// v1：安全第一。全部置き換え（delete → insert）
    func replaceIngredientRows(recipeId: UUID, rows: [IngredientRow]) {
        guard let db = db else { return }

        queue.sync {
            // トランザクションで一括確定（途中落ちでも中途半端になりにくい）
            sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
            defer { sqlite3_exec(db, "COMMIT;", nil, nil, nil) }

            // 1) delete
            do {
                let delSQL = "DELETE FROM ingredient_rows WHERE recipeId = ?;"
                var delStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, delSQL, -1, &delStmt, nil) == SQLITE_OK {
                    defer { sqlite3_finalize(delStmt) }
                    sqlite3_bind_text(delStmt, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)
                    if sqlite3_step(delStmt) != SQLITE_DONE {
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        print("❌ replaceIngredientRows delete error: \(errorMsg)")
                    }
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
                        // header自身の blockId は nil でOK（復元は kind で判定する）
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
                        let errorMsg = String(cString: sqlite3_errmsg(db))
                        print("❌ replaceIngredientRows insert error: \(errorMsg)")
                    }
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                print("❌ replaceIngredientRows prepare error: \(errorMsg)")
            }
        }
    }
}
