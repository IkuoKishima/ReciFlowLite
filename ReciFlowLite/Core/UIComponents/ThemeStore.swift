/// MARK: - ThemeStore.swift

import SwiftUI
import Combine

@MainActor
final class ThemeStore: ObservableObject {
    @AppStorage("ui.paperStyle") private var paperStyleRaw: String = PaperStyle.classicPaper.rawValue

    var paperStyle: PaperStyle {
        get { PaperStyle(rawValue: paperStyleRaw) ?? .classicPaper }
        set { paperStyleRaw = newValue.rawValue }
    }
}
