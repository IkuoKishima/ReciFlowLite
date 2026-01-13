/// MARK: - PaperStyle.swift

import SwiftUI

enum PaperStyle: String, CaseIterable, Identifiable {
    case classicPaper
    case warmCream
    case mint
    case sky
    case lavender
    case graphite
    case nightInk
    case blackPaper
    case sepia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classicPaper: return "クラシック"
        case .warmCream:    return "クリーム"
        case .mint:         return "ミント"
        case .sky:          return "スカイ"
        case .lavender:     return "ラベンダー"
        case .graphite:     return "グラファイト"
        case .nightInk:     return "ナイトインク"
        case .blackPaper:   return "ブラック"
        case .sepia:        return "セピア"
        }
    }

    func paperColor(defaultPaper: Color = MaterialTheme.paper, scheme: ColorScheme) -> Color {
        // 「紙色」だけ変える。ダークでも破綻しにくいように軽く補正。
        switch self {
        case .classicPaper:
            return scheme == .dark ? Color.white.opacity(0.08) : defaultPaper

        case .warmCream:
            return scheme == .dark ? Color.white.opacity(0.07) : Color(hex: "#FBF2D6")

        case .mint:
            return scheme == .dark ? Color.green.opacity(0.10) : Color(hex: "#E6FBF2")

        case .sky:
            return scheme == .dark ? Color.blue.opacity(0.10) : Color(hex: "#E8F3FF")

        case .lavender:
            return scheme == .dark ? Color.purple.opacity(0.10) : Color(hex: "#F0E9FF")

        case .graphite:
            return scheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.04)

        case .nightInk:
            return scheme == .dark ? Color.white.opacity(0.05) : Color(hex: "#EEF3FF")
        case .blackPaper:
            // 真っ黒は目が痛いので少しだけ浮かせる（おすすめ）
            return Color.black.opacity(scheme == .dark ? 0.92 : 0.88)
            // もっと“漆黒”なら ↓
            // return Color.black


        case .sepia:
            return scheme == .dark ? Color.orange.opacity(0.08) : Color(hex: "#F6E4C9")
        }
    }
}
extension PaperStyle {

    /// “白インクが必要か” を scheme も含めて判断する
    func prefersLightInk(scheme: ColorScheme) -> Bool {
        switch self {
        case .blackPaper:
            return true                  // 常に白インク
        case .graphite, .nightInk:
            return scheme == .dark       // ダークの時だけ白インク
        default:
            return false
        }
    }

    func inkColor(scheme: ColorScheme) -> Color {
        if prefersLightInk(scheme: scheme) {
            return Color.white.opacity(0.92)
        } else {
            return MaterialTheme.ink
        }
    }
}
