/// MARK: - DatabaseManager.swift

import Foundation
import SQLite3

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "DatabaseManager") // 直列キュー

    // ✅ DBパスを保持（実行時復旧で必要）
    private let dbURL: URL

    // ✅ 実行時に致命エラーを検知したら、一旦「隔離中」フラグで暴走防止
    private var isRecovering = false

    private init() {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        self.dbURL = urls[0].appendingPathComponent("ReciFlowLite.sqlite")

        DBLOG("📁 Database path: \(dbURL.path)")

        // 起動時：open → quick_check → NGなら隔離して作り直し
        guard openOrRecover(at: dbURL, reason: "startup") else {
            DBLOG("❌ Failed to open database even after recovery.")
            self.db = nil
            return
        }

        // create & migrate
        createTablesIfNeeded()
        migrateIfNeeded()

        // 起動成功したら、バックアップも一度確保（任意だけどおすすめ）
        backupDatabaseNow(tag: "startup_ok")
    }

//    deinit {
//        close()
//    }

    private func closeLocked() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func close() {
        queue.sync {
            closeLocked()
        }
    }




    // MARK: - Open / Configure / Integrity / Recover

    private func openOrRecover(at url: URL, reason: String) -> Bool {
        if open(at: url) == false {
            DBLOG("⚠️ open failed (\(reason)) → quarantine & recreate")
            quarantineDatabaseFile(at: url, reason: "open_failed_\(reason)")
            guard open(at: url) else { return false }
        }

        // open成功 → PRAGMA設定
        configureConnection()

        // 健全性チェック（軽量）
        if quickCheckIsOK() { return true }

        DBLOG("⚠️ quick_check failed (\(reason)) → quarantine & recreate")

        close()
        quarantineDatabaseFile(at: url, reason: "quick_check_failed_\(reason)")

        guard open(at: url) else { return false }
        configureConnection()

        if quickCheckIsOK() { return true }

        DBLOG("❌ quick_check still failing after recreate")
        return false
    }

    private func open(at url: URL) -> Bool {
        var connection: OpaquePointer?
        let rc = sqlite3_open(url.path, &connection)
        if rc == SQLITE_OK {
            self.db = connection
            DBLOG("✅ Database opened")
            return true
        } else {
            let msg = connection.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            DBLOG("❌ sqlite3_open error: \(msg)")
            if let c = connection { sqlite3_close(c) }
            return false
        }
    }

    /// ✅ フリーズ/ロック待ちを抑えつつ、堅牢性も保つ設定
    private func configureConnection() {
        guard let db else { return }

        // ロック待ちで永遠に固まらないように
        sqlite3_busy_timeout(db, 2000) // 2秒（好みで調整）

        // WALは「アプリが落ちた」系に強い
        _ = sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
        _ = sqlite3_exec(db, "PRAGMA synchronous=NORMAL;", nil, nil, nil)

        // 任意（外部キー使ってるなら）
        _ = sqlite3_exec(db, "PRAGMA foreign_keys=ON;", nil, nil, nil)
        
        //拡張コードを有効化
        _ = sqlite3_extended_result_codes(db, 1)


    #if DEBUG
        // 任意：WALの自動チェックポイント
        _ = sqlite3_exec(db, "PRAGMA wal_autocheckpoint=1000;", nil, nil, nil)
    #endif
    }

    /// 軽量版：PRAGMA quick_check(1)
    private func quickCheckIsOK() -> Bool {
        guard let db else { return false }

        return queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            let sql = "PRAGMA quick_check(1);"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ quick_check prepare failed: \(msg)")
                return false
            }

            if sqlite3_step(stmt) == SQLITE_ROW {
                if let c = sqlite3_column_text(stmt, 0) {
                    let s = String(cString: c)
                    if s.lowercased() == "ok" {
                        DBLOG("✅ quick_check OK")
                        return true
                    } else {
                        DBLOG("❌ quick_check returned: \(s)")
                        return false
                    }
                }
            }

            DBLOG("❌ quick_check no row")
            return false
        }
    }

    // MARK: - Runtime Fatal Error Handling

    /// ✅ 致命エラー判定（環境差が出る extended 定数は使わない）
//    private func isFatalSQLiteCode(_ rc: Int32) -> Bool {
//        let primary = rc & 0xFF  // 下位8bitが “親コード” になる
//
//        switch primary {
//        case SQLITE_CORRUPT, SQLITE_NOTADB:
//            return true
//        case SQLITE_IOERR:
//            return true
//        case SQLITE_FULL:
//            return true
//        default:
//            return false
//        }
//    }
    
    /// ✅ db から拡張errcodeを取り、それで致命判定する（rcより正確）
    private func isFatalSQLiteError(db: OpaquePointer?, rc: Int32) -> Bool {
        // 拡張errcodeが取れるなら優先（取れない場合は rc を使う）
        let code: Int32 = db.map { sqlite3_extended_errcode($0) } ?? rc
        let primary = code & 0xFF

        switch primary {
        case SQLITE_CORRUPT, SQLITE_NOTADB:
            return true
        case SQLITE_IOERR:
            return true
        case SQLITE_FULL:
            return true
        default:
            return false
        }
    }

    /// ✅ queue上で呼ぶ前提（= sync/async ブロックの中）
    private func handleFatalDatabaseErrorLocked(context: String, rc: Int32) {
        guard isRecovering == false else { return }
        isRecovering = true
        defer { isRecovering = false }

        // まず msg を作る（先に使うから）
        let msg = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"

        // 拡張errcode（dbがあれば拾う。なければ rc で代用）
        let ext = db.map { sqlite3_extended_errcode($0) } ?? rc

        // ログは1回で十分（重複を消す）
        DBLOG("🧨 FATAL DB error: rc=\(rc) ext=\(ext) ctx=\(context) msg=\(msg)")
        DBLOG("🧯 quarantine & recreate (runtime)")

        // close → quarantine → 新規open → create/migrate
        closeLocked()
//        close()
        quarantineDatabaseFile(at: dbURL, reason: "runtime_\(context)_rc\(rc)")

        // 新規DBとして復旧
        if open(at: dbURL) {
            configureConnection()
            createTablesIfNeeded()
            migrateIfNeeded()
            backupDatabaseNow(tag: "runtime_recovered")
            DBLOG("✅ runtime recovery completed")
        } else {
            DBLOG("❌ runtime recovery failed to open new db")
        }
    }

    /// 壊れたDBを退避（同名を潰さないようタイムスタンプ付き）
    private func quarantineDatabaseFile(at url: URL, reason: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }

        let ts = Self.timestampString()
        let folder = url.deletingLastPathComponent()
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.isEmpty ? "sqlite" : url.pathExtension

        let newName = "\(base)_Corrupted_\(ts)_\(reason).\(ext)"
        let dst = folder.appendingPathComponent(newName)

        do {
            try fm.moveItem(at: url, to: dst)
            DBLOG("🧯 DB quarantined → \(dst.lastPathComponent)")
        } catch {
            DBLOG("⚠️ quarantine move failed: \(error.localizedDescription)")
            do {
                try fm.copyItem(at: url, to: dst)
                try fm.removeItem(at: url)
                DBLOG("🧯 DB copied+removed → \(dst.lastPathComponent)")
            } catch {
                DBLOG("❌ quarantine failed: \(error.localizedDescription)")
            }
        }

        cleanupSidecarFiles(for: url)
    }

    private func cleanupSidecarFiles(for url: URL) {
        let fm = FileManager.default
        let wal = URL(fileURLWithPath: url.path + "-wal")
        let shm = URL(fileURLWithPath: url.path + "-shm")

        if fm.fileExists(atPath: wal.path) {
            try? fm.removeItem(at: wal)
            DBLOG("🧹 removed -wal")
        }
        if fm.fileExists(atPath: shm.path) {
            try? fm.removeItem(at: shm)
            DBLOG("🧹 removed -shm")
        }
    }

    private static func timestampString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd_HHmmss"
        return f.string(from: Date())
    }


    // MARK: - Schema / Migration

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
        createIngredientTablesIfNeeded()
    }

    private func migrateIfNeeded() {
        let currentVersion = 2
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: "schemaVersion")

        ensureRecipesDeletedAtColumn()

        if storedVersion == 0 {
            defaults.set(currentVersion, forKey: "schemaVersion")
            DBLOG("🔀 Schema initialized to \(currentVersion)")
            return
        }

        guard storedVersion < currentVersion else { return }

        defaults.set(currentVersion, forKey: "schemaVersion")
        DBLOG("🔀 Schema migrated from \(storedVersion) to \(currentVersion)")
    }

    private func ensureRecipesDeletedAtColumn() {
        guard let db = db else { return }

        queue.sync {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }

            if sqlite3_prepare_v2(db, "PRAGMA table_info(recipes);", -1, &stmt, nil) != SQLITE_OK {
                DBLOG("❌ PRAGMA table_info(recipes) failed")
                return
            }

            var hasDeletedAt = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cName = sqlite3_column_text(stmt, 1) {
                    let name = String(cString: cName)
                    if name == "deletedAt" { hasDeletedAt = true; break }
                }
            }

            guard !hasDeletedAt else { return }

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

    // MARK: - Internal SQL helper (fatal-safe)

    private func execute(sql: String, context: String = "exec") {
        guard let db else { return }

        queue.sync {
            var errMsg: UnsafeMutablePointer<Int8>?
            let rc = sqlite3_exec(db, sql, nil, nil, &errMsg)

            if rc == SQLITE_OK {
                return
            }

            let msg = errMsg.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(db))
            if let errMsg { sqlite3_free(errMsg) }

            DBLOG("❌ SQL exec error: rc=\(rc) ctx=\(context) msg=\(msg)")

            if isFatalSQLiteError(db: db, rc: rc) {
                handleFatalDatabaseErrorLocked(context: context, rc: rc)
            }
        }
    }


    // MARK: - Public API (Recipes)

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
        guard db != nil else { return false }

        return await withCheckedContinuation { continuation in
            queue.async { [weak self] in
                guard let self, let db = self.db else {
                    continuation.resume(returning: false)
                    return
                }

                let sql = """
                INSERT INTO recipes (id, title, memo, createdAt, updatedAt)
                VALUES (?, ?, ?, ?, ?);
                """

                var stmt: OpaquePointer?
                let prc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
                if prc != SQLITE_OK {
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ insert prepare error: rc=\(prc) msg=\(msg)")
                    if self.isFatalSQLiteError(db: db, rc: prc) {
                        self.handleFatalDatabaseErrorLocked(context: "insert_prepare", rc: prc)
                    }
                    continuation.resume(returning: false)
                    return
                }

                defer { sqlite3_finalize(stmt) }

                DatabaseManager.bind(recipe: recipe, to: stmt)

                let src = sqlite3_step(stmt)
                if src == SQLITE_DONE {
                    DBLOG("✅ Inserted recipe: \(recipe.id)")
                    // ✅ 書き込み成功 → バックアップ更新
                    self.backupDatabaseNow(tag: "insert_recipe")
                    continuation.resume(returning: true)
                } else {
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ insert step error: rc=\(src) msg=\(msg)")
                    if self.isFatalSQLiteError(db: db, rc: src) {
                        self.handleFatalDatabaseErrorLocked(context: "insert_step", rc: src)
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }

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

            let prc = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
            if prc == SQLITE_OK {
                sqlite3_bind_text(statement, 1, recipe.title, -1, SQLITE_TRANSIENT)
                sqlite3_bind_text(statement, 2, recipe.memo,  -1, SQLITE_TRANSIENT)
                sqlite3_bind_double(statement, 3, recipe.updatedAt.timeIntervalSince1970)
                sqlite3_bind_text(statement, 4, recipe.id.uuidString, -1, SQLITE_TRANSIENT)

                let src = sqlite3_step(statement)
                if src == SQLITE_DONE {
                    DBLOG("✅ Updated recipe: \(recipe.id)")
                    // 任意：更新でもバックアップを取りたいなら
                    // self.backupDatabaseNow(tag: "update_recipe")
                } else {
                    let errorMsg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ update step error: rc=\(src) msg=\(errorMsg)")
                    if isFatalSQLiteError(db: db, rc: src) {
                        handleFatalDatabaseErrorLocked(context: "update_step", rc: src)
                    }
                }
            } else {
                let errorMsg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ update prepare error: rc=\(prc) msg=\(errorMsg)")
                if isFatalSQLiteError(db: db, rc: prc) {
                    handleFatalDatabaseErrorLocked(context: "update_prepare", rc: prc)
                }
            }
        }
    }


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

    private static func readRecipeRow(statement: OpaquePointer?) -> Recipe? {
        guard let stmt = statement else { return nil }
        guard
            let idCString = sqlite3_column_text(stmt, 0),
            let titleCString = sqlite3_column_text(stmt, 1),
            let memoCString = sqlite3_column_text(stmt, 2)
        else { return nil }

        let idString = String(cString: idCString)
        let title = String(cString: titleCString)
        let memo = String(cString: memoCString)

        let createdAtTime = sqlite3_column_double(stmt, 3)
        let updatedAtTime = sqlite3_column_double(stmt, 4)

        guard let id = UUID(uuidString: idString) else { return nil }

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
    
    // MARK: - Local Backup (sqlite3_backup)

    /// 保存先：Documents 内に世代バックアップを持つ
    private var backupURL1: URL {
        dbURL.deletingLastPathComponent().appendingPathComponent("ReciFlowLite_backup.sqlite")
    }
    private var backupURL2: URL {
        dbURL.deletingLastPathComponent().appendingPathComponent("ReciFlowLite_backup2.sqlite")
    }

    /// ✅ 書き込み成功後などに呼ぶ（queue上から呼んでもOK）
    private func backupDatabaseNow(tag: String) {
        guard let db else { return }

        queue.sync {
            // WALを使っているので、バックアップ前に軽くチェックポイント（任意）
            _ = sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)

            // 世代ローテーション：backup → backup2
            rotateBackups()

            // sqlite3_backup で本体 → backup1 にコピー
            var dst: OpaquePointer?
            let openRC = sqlite3_open(backupURL1.path, &dst)
            guard openRC == SQLITE_OK, let dst = dst else {
                DBLOG("❌ backup open failed rc=\(openRC)")
                if let dst { sqlite3_close(dst) }
                return
            }
            defer { sqlite3_close(dst) }

            guard let b = sqlite3_backup_init(dst, "main", db, "main") else {
                DBLOG("❌ sqlite3_backup_init failed: \(String(cString: sqlite3_errmsg(dst)))")
                return
            }

            let stepRC = sqlite3_backup_step(b, -1) // 全ページ
            let finishRC = sqlite3_backup_finish(b)

            if stepRC == SQLITE_DONE && finishRC == SQLITE_OK {
                DBLOG("💾 Backup OK (\(tag)) → \(backupURL1.lastPathComponent)")
            } else {
                DBLOG("❌ Backup failed tag=\(tag) stepRC=\(stepRC) finishRC=\(finishRC)")
            }
        }
    }

    private func rotateBackups() {
        let fm = FileManager.default

        // backup1 があれば backup2 へ
        if fm.fileExists(atPath: backupURL1.path) {
            do {
                if fm.fileExists(atPath: backupURL2.path) {
                    try fm.removeItem(at: backupURL2)
                }
                try fm.moveItem(at: backupURL1, to: backupURL2)
            } catch {
                DBLOG("⚠️ rotateBackups failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Ingredient tables

extension DatabaseManager {

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

    func replaceIngredientRows(recipeId: UUID, rows: [IngredientRow]) {
        guard db != nil else { return }

        // ✅ fatal を検知したら、queue.sync の外で復旧を走らせる（defer事故を避ける）
        var pendingFatal: (context: String, rc: Int32)?

        queue.sync { [weak self] in
            guard let self, let db = self.db else { return }

            func markFatalIfNeeded(_ context: String, _ rc: Int32) {
                if pendingFatal == nil, self.isFatalSQLiteError(db: db, rc: rc) {
                    pendingFatal = (context, rc)
                }
            }

            func rollbackIfNeeded(_ reason: String) {
                let rrc = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
                if rrc != SQLITE_OK {
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ replaceIngredientRows ROLLBACK error: rc=\(rrc) reason=\(reason) msg=\(msg)")
                    markFatalIfNeeded("replaceIngredientRows_rollback", rrc)
                }
            }

            // --- BEGIN ---
            let brc = sqlite3_exec(db, "BEGIN IMMEDIATE TRANSACTION;", nil, nil, nil)
            if brc != SQLITE_OK {
                let msg = String(cString: sqlite3_errmsg(db))
                DBLOG("❌ replaceIngredientRows BEGIN error: rc=\(brc) msg=\(msg)")
                markFatalIfNeeded("replaceIngredientRows_begin", brc)
                return
            }

            var ok = true

            // --- DELETE ---
            do {
                let delSQL = "DELETE FROM ingredient_rows WHERE recipeId = ?;"
                var delStmt: OpaquePointer?
                let prc = sqlite3_prepare_v2(db, delSQL, -1, &delStmt, nil)
                if prc == SQLITE_OK, let delStmt {
                    defer { sqlite3_finalize(delStmt) }
                    sqlite3_bind_text(delStmt, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)

                    let src = sqlite3_step(delStmt)
                    if src != SQLITE_DONE {
                        ok = false
                        let msg = String(cString: sqlite3_errmsg(db))
                        DBLOG("❌ replaceIngredientRows delete step error: rc=\(src) msg=\(msg)")
                        markFatalIfNeeded("replaceIngredientRows_delete_step", src)
                    }
                } else {
                    ok = false
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ replaceIngredientRows delete prepare error: rc=\(prc) msg=\(msg)")
                    markFatalIfNeeded("replaceIngredientRows_delete_prepare", prc)
                }
            }

            // --- INSERT ---
            if ok {
                let insSQL = """
                INSERT INTO ingredient_rows
                (id, recipeId, kind, orderIndex, blockId, title, name, amount, unit)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """

                var insStmt: OpaquePointer?
                let prc = sqlite3_prepare_v2(db, insSQL, -1, &insStmt, nil)
                if prc == SQLITE_OK, let insStmt {
                    defer { sqlite3_finalize(insStmt) }

                    for (index, row) in rows.enumerated() {
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

                        if let blockId { sqlite3_bind_text(insStmt, 5, blockId, -1, SQLITE_TRANSIENT) }
                        else { sqlite3_bind_null(insStmt, 5) }

                        if let title { sqlite3_bind_text(insStmt, 6, title, -1, SQLITE_TRANSIENT) }
                        else { sqlite3_bind_null(insStmt, 6) }

                        if let name { sqlite3_bind_text(insStmt, 7, name, -1, SQLITE_TRANSIENT) }
                        else { sqlite3_bind_null(insStmt, 7) }

                        if let amount { sqlite3_bind_text(insStmt, 8, amount, -1, SQLITE_TRANSIENT) }
                        else { sqlite3_bind_null(insStmt, 8) }

                        if let unit { sqlite3_bind_text(insStmt, 9, unit, -1, SQLITE_TRANSIENT) }
                        else { sqlite3_bind_null(insStmt, 9) }

                        let src = sqlite3_step(insStmt)
                        if src != SQLITE_DONE {
                            ok = false
                            let msg = String(cString: sqlite3_errmsg(db))
                            DBLOG("❌ replaceIngredientRows insert step error: rc=\(src) msg=\(msg)")
                            markFatalIfNeeded("replaceIngredientRows_insert_step", src)
                            break
                        }
                    }
                } else {
                    ok = false
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ replaceIngredientRows insert prepare error: rc=\(prc) msg=\(msg)")
                    markFatalIfNeeded("replaceIngredientRows_insert_prepare", prc)
                }
            }

            // --- COMMIT / ROLLBACK ---
            if ok {
                let crc = sqlite3_exec(db, "COMMIT;", nil, nil, nil)
                if crc != SQLITE_OK {
                    let msg = String(cString: sqlite3_errmsg(db))
                    DBLOG("❌ replaceIngredientRows COMMIT error: rc=\(crc) msg=\(msg)")
                    markFatalIfNeeded("replaceIngredientRows_commit", crc)
                    rollbackIfNeeded("commit_failed")
                } else {
                    self.backupDatabaseNow(tag: "replaceIngredientRows_commit")
                }
            } else {
                rollbackIfNeeded("op_failed")
            }
        }

        // ✅ sync の外で復旧を実行（トランザクションdefer事故を避ける）
        if let fatal = pendingFatal {
            queue.sync { [weak self] in
                guard let self else { return }
                self.handleFatalDatabaseErrorLocked(context: fatal.context, rc: fatal.rc)
            }
        }
    }


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

    private func _fetchIngredientRowsSync(recipeId: UUID) -> [IngredientRow] {
        guard let db = db else { return [] }

        let sql = """
        SELECT id, kind, orderIndex, blockId, title, name, amount, unit
        FROM ingredient_rows
        WHERE recipeId = ?
        ORDER BY orderIndex ASC;
        """

        var result: [IngredientRow] = []

        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_text(statement, 1, recipeId.uuidString, -1, SQLITE_TRANSIENT)

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let idC = sqlite3_column_text(statement, 0) else { continue }

                let kindRaw = sqlite3_column_int(statement, 1)
                let kind = IngredientRowKind(rawValue: kindRaw) ?? .single

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

#if DEBUG
extension DatabaseManager {
    /// 次回起動で必ず quick_check が落ちるように、DB先頭を破壊する（復旧テスト用）
    func debugCorruptDatabaseFile() {
        let fm = FileManager.default
        let urls = fm.urls(for: .documentDirectory, in: .userDomainMask)
        let dbURL = urls[0].appendingPathComponent("ReciFlowLite.sqlite")

        close()

        guard fm.fileExists(atPath: dbURL.path) else {
            DBLOG("⚠️ debugCorruptDatabaseFile: db file not found")
            return
        }

        do {
            var data = try Data(contentsOf: dbURL)
            if data.count >= 32 {
                for i in 0..<32 { data[i] = UInt8.random(in: 0...255) }
            } else {
                data = Data()
            }
            try data.write(to: dbURL, options: .atomic)
            DBLOG("🧪 DB corrupted for test: \(dbURL.lastPathComponent)")
        } catch {
            DBLOG("❌ debugCorruptDatabaseFile failed: \(error.localizedDescription)")
        }
    }
}
#endif
