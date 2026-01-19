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
        switch self {

        // 明るい紙（黒インク）
        case .classicPaper:
            return scheme == .dark ? Color(hex: "#E6E0D6").opacity(0.22) : defaultPaper

        case .warmCream:
            return scheme == .dark
              ? Color(hex: "#E8DAB0").opacity(0.22)
              : Color(hex: "#FBF2D6")


        case .sepia:
            return scheme == .dark ? Color(hex: "#3A2A1E") : Color(hex: "#F6E4C9")

        // 暗い紙（白インク）
        case .mint:
            return scheme == .dark ? Color(hex: "#0E2A22") : Color(hex: "#E6FBF2")

        case .sky:
            return scheme == .dark ? Color(hex: "#0D2236") : Color(hex: "#E8F3FF")

        case .lavender:
            return scheme == .dark ? Color(hex: "#241B3A") : Color(hex: "#F0E9FF")

        case .graphite:
            return scheme == .dark ? Color(hex: "#121417") : Color(hex: "#F2F3F5").opacity(0.55)
            // ↑ ライト側も “ただの黒0.04” より、グラファイトっぽい“薄グレー紙”に

        case .nightInk:
            return scheme == .dark ? Color(hex: "#0B1020") : Color(hex: "#EEF3FF")

        case .blackPaper:
            return Color.black.opacity(scheme == .dark ? 0.92 : 0.88)
        }
    }

}
extension PaperStyle {

    /// “紙面（背景）が暗い” ＝ 白インクが必要
    /// ✅ 方針：
    /// - OSがダークなら、基本的に全紙面を「暗い」扱い（白インク）
    /// - OSがライトなら、blackPaper だけ「暗い」扱い（白インク）
    func isDarkSurface(scheme: ColorScheme) -> Bool {
        if scheme == .dark { return true }
        return self == .blackPaper
    }

    func inkColor(scheme: ColorScheme) -> Color {
        isDarkSurface(scheme: scheme)
        ? Color.white.opacity(0.92)
        : Color.black.opacity(0.92)
    }

    func secondaryInkColor(scheme: ColorScheme) -> Color {
        isDarkSurface(scheme: scheme)
        ? Color.white.opacity(0.55)
        : Color.black.opacity(0.55)
    }

    func separatorColor(scheme: ColorScheme) -> Color {
        isDarkSurface(scheme: scheme)
            ? Color.white.opacity(0.18)   // 暗紙・黒背景・ダークモード
            : Color.black.opacity(0.16)   // 明紙・ライトモード
    }

}
extension PaperStyle {
    var isDarkBackground: Bool {
        self == .blackPaper
    }
}
