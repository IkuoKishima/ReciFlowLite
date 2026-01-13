/// MARK: - MaterialTheme.swift

import SwiftUI

struct MaterialTheme {
    // 光源方向（右上からの光）
    static let lightDirection = UnitPoint(x: 0.82, y: 0.18)

    // ベースカラー（紙とインク）
    static let paper = Color(hex: "#F9F8F7")
    static let ink   = Color(hex: "#1C1C1E")
    static let accent = Color(hex: "#F4A261")

    // 🆕 ロゴ／起動画面用の淡いグラデーション
    static let logoGradientTop    = Color(hex: "#E5F4F1")  // ほぼ白に近いミント
    static let logoGradientBottom = Color(hex: "#F9FBFF")  // うっすら青みの白

    // 🆕 ロゴの背後に置く「液体のハロー」
    static let logoHalo = Color.white.opacity(0.85)

    // ガラス設定（Liquid Glass 共通）
    static let glassOpacity: CGFloat    = 0.22
    static let iconOpacity: CGFloat     = 0.75
    static let glossHighlight: CGFloat  = 0.35
    static let shadowDepth: CGFloat     = 0.12

    // フォントシステム
    struct FontSet {
        // ロゴ：少しだけ tracking を広げるとき用
        static let logo   = Font.system(size: 48, weight: .heavy, design: .rounded)
        static let title  = Font.system(size: 22, weight: .semibold, design: .rounded)
        static let body   = Font.system(size: 17, weight: .regular, design: .default)
        static let caption = Font.system(size: 14, weight: .regular, design: .default)
    }
}
extension MaterialTheme {
    // 編集画面（IngredientEngine）専用
    static let editBackground  = paper
    static let blockHeaderText = ink
    static let blockHeaderUnderline = accent.opacity(0.8)

    // ドック用
    static let dockBackground  = Color.black.opacity(0.05)
    static let dockBorder      = Color.white.opacity(0.3)

    // Reader モード（ページめくり）
    static let readerPaper = paper
    static let readerSectionTitle = ink
    static let readerAccentLine = accent.opacity(0.5)
}

// 16進カラーコードから Color を生成するユーティリティ
extension Color {
    /// 16進カラーコード文字列からColorを生成
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}
