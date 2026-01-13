/// MARK: - ExportModels.swift

import Foundation

// エクスポート全体
struct RFExportPackage: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let app: String
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
