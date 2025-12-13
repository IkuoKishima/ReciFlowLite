import Foundation
import SQLite3
import SQLite

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

