/// MARK: - RecipeMetaStrip.swift

import SwiftUI

struct RecipeMetaStrip: View {
    let createdAt: Date
    let updatedAt: Date

    // 世界対応：ロケールに委ねる（混ぜずに統一）
    private var createdText: String {
        createdAt.formatted(date: .numeric, time: .omitted)
    }
    private var updatedText: String {
        updatedAt.formatted(date: .numeric, time: .shortened)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(createdText)
            Text("•")
            Text(updatedText)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.leading, 6)  // タイトルの文字面に寄せる（好み）
        .padding(.top, -6)     // タイトルとの距離（好み）
        .accessibilityLabel("Created \(createdText), Updated \(updatedText)")
    }
}
