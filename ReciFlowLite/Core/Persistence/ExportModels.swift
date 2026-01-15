/// MARK: - ExportModels.swift

import Foundation

// エクスポート全体
struct RFExportPackage: Codable {
    
    let schemaVersion: Int // Export JSON形式のバージョン（インポート互換の判断に使う）
    let dbSchemaVersion: Int // DBスキーマ世代（SQLiteの列構成の世代）
    let exportedAt: Date
    let app: String

    /// 任意（将来デバッグで超助かる）
    let appVersion: String?
    let build: String?
    let summary: RFExportSummary
    let recipes: [RFExportRecipe]
}


// レシピ単位
struct RFExportRecipe: Codable {
    let id: UUID
    let title: String
    let memo: String
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?   // 今後の完全同期に必須
    
    let ingredientRows: [RFExportIngredientRow]
}

// ingredient_rows の1行（blockHeader / single / blockItem を共通化）
struct RFExportIngredientRow: Codable {
    enum Kind: Int, Codable {
        case single = 0
        case blockHeader = 1
        case blockItem = 2
    }

    let id: UUID
    let kind: Kind
    let orderIndex: Int
    let blockId: UUID?
    let title: String?
    let name: String?
    let amount: String?
    let unit: String?
}

struct RFExportSummary: Codable {
    let recipesTotal: Int
    let recipesDeleted: Int

    let ingredientRowsTotal: Int
    let rowsSingle: Int
    let rowsBlockHeader: Int
    let rowsBlockItem: Int

    /// 正規化や検出で出た警告数（将来の診断に便利）
    let warnings: Int
}
